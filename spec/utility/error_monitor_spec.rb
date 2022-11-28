#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'utility/error_monitor'

describe Utility::ErrorMonitor do
  it 'has expected default values' do
    monitor = Utility::ErrorMonitor.new
    expect(monitor.instance_variable_get('@max_errors')).to eq(1000)
    expect(monitor.instance_variable_get('@max_consecutive_errors')).to eq(10)
    expect(monitor.instance_variable_get('@max_error_ratio')).to eq(0.15)
    expect(monitor.instance_variable_get('@window_size')).to eq(100)
  end

  it 'raises an error after too many errors in a window' do
    monitor = Utility::ErrorMonitor.new(:max_error_ratio => 0.15, window_size: 100)

    10.times do
      monitor.note_error(StandardError.new)
    end

    84.times do
      monitor.note_success
    end

    5.times do
      monitor.note_error(StandardError.new)
    end

    expect { monitor.note_error(StandardError.new) }.to raise_error(Utility::ErrorMonitor::MaxErrorsInWindowExceededError)
  end

  context 'when successes and failures were reported before' do
    # Regression test.
    # Problem fixed was that monitor incorrectly calculates max_error_ratio - it never
    # actually considered either ratio or window size - it was always raising an error if
    # window_size * max_error_ratio errors happened, which is 15 in case of this setup.
    # What it should do is really consider the window and error ratio, e.g:
    # 85 documents were correctly ingested, 15 failed. Window will be: 85 x success, 15 x failure,
    # error_ratio = 0.15, but condition to raise is max_error_ratio < error_ratio - it's false, so
    # no error is raised.
    #
    # Then 90 documents were ingested correctly, window moves and will be: 10 x failure, 90 x success,
    # error_ratio = 0.1; Then 10 errors happen, but error_ratio will stay the same because window will be
    # 90 x success, 10 x failure.
    let(:monitor) { Utility::ErrorMonitor.new(:max_error_ratio => 0.15, window_size: 100, max_consecutive_errors: 100) }
    before(:each) do
      # Setup is 100 triggers:
      # 5 x failure; 40 x success; 5 x failure; 40 x success, error_ratio = 0.1
      2.times do
        5.times do
          monitor.note_error(StandardError.new)
        end

        40.times do
          monitor.note_success
        end
      end
    end

    it 'raises an error after too many errors in a window' do
      expect {
        # Before:
        # 5 x failure; 40 x success; 5 x failure; 40 x success, real error_ratio = 0.1
        # After:
        # 40 x success; 5 x failure; 40 x success; 5 x failure, real error_ratio = 0.1
        5.times do
          monitor.note_error(StandardError.new)
        end

        # Before:
        # 40 x success; 5 x failure; 40 x success; 5 x failure, real error_ratio = 0.1
        # After:
        # 1 x success; 5x failure; 94 x success, real_error_ratio = 0.05
        94.times do
          monitor.note_success
        end

        # Before:
        # 1 x success; 5 x failure; 94 x success, real_error_ratio = 0.05
        # After:
        # 85 x success, 15 x failure, real_error_ratio = 0.15.
        # Any error within next 85 documents should trigger the MaxErrorsInWindowExceededError
        15.times do
          monitor.note_error(StandardError.new)
        end
      }.to_not raise_error

      expect { monitor.note_error(StandardError.new) }.to raise_error(Utility::ErrorMonitor::MaxErrorsInWindowExceededError)
    end
  end

  it 'raises an error after too many failures in a row' do
    monitor = Utility::ErrorMonitor.new(:max_consecutive_errors => 3)
    expect { add_errors(monitor, 4) }.to raise_error do |e|
      expect(e).to be_a(Utility::ErrorMonitor::MaxSuccessiveErrorsExceededError)
      expect(e.cause.message).to eq('Error 4')
    end
  end

  it 'raises an error after too many total failures' do
    monitor = Utility::ErrorMonitor.new(:max_errors => 5, :max_consecutive_errors => 2)
    expect { add_errors(monitor, 6, :alternate_success => true) }.to raise_error do |e|
      expect(e).to be_a(Utility::ErrorMonitor::MaxErrorsExceededError)
      expect(e.cause.message).to eq('Error 6')
    end
  end

  it 'raises an error after too many failures in a window' do
    monitor = Utility::ErrorMonitor.new(:max_consecutive_errors => 15)
    expect { add_errors(monitor, 15) }.to_not raise_error
    monitor.note_success
    expect { monitor.note_error(StandardError.new("The hair that broke the camel's back")) }.to raise_error do |e|
      expect(e).to be_a(Utility::ErrorMonitor::MaxErrorsInWindowExceededError)
      expect(e.cause.message).to eq("The hair that broke the camel's back")
    end
  end

  it 'raises an error when finalized even if the window is not full' do
    monitor = Utility::ErrorMonitor.new
    expect { add_errors(monitor, 10, :alternate_success => true) }.to_not raise_error
    expect { monitor.finalize }.to raise_error do |e|
      expect(e).to be_a(Utility::ErrorMonitor::MaxErrorsInWindowExceededError)
      expect(e.cause.message).to eq('Error 10')
    end
  end

  it 'stores up to :error_buffer_size last errors' do
    monitor = Utility::ErrorMonitor.new(:max_consecutive_errors => 15, :error_queue_size => 10)
    expect { add_errors(monitor, 15) }.to change { monitor.error_queue.size }.from(0).to(10)
    expect(monitor.error_queue.first.error_message).to match(/Error 6/)
    expect(monitor.error_queue.last.error_message).to match(/Error 15/)
  end

  def add_errors(monitor, num_errors, alternate_success: false)
    num_errors.times do |i|
      monitor.note_error(StandardError.new("Error #{i + 1}"))
      monitor.note_success if alternate_success
    end
  end
end
