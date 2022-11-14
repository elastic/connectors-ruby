#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'utility/error_monitor'

describe Utility::ErrorMonitor do
  let(:connector) { double }

  before(:each) do
    allow(connector).to receive(:log_debug)
  end

  it 'has expected default values' do
    monitor = Utility::ErrorMonitor.new(:connector => connector)
    expect(monitor.instance_variable_get('@max_errors')).to eq(1000)
    expect(monitor.instance_variable_get('@max_consecutive_errors')).to eq(10)
    expect(monitor.instance_variable_get('@max_error_ratio')).to eq(0.15)
    expect(monitor.instance_variable_get('@window_size')).to eq(100)
  end

  it 'raises an error after too many failures in a row' do
    monitor = Utility::ErrorMonitor.new(:connector => connector, :max_consecutive_errors => 3)
    expect { add_errors(monitor, 4) }.to raise_error do |e|
      expect(e).to be_a(Utility::ErrorMonitor::MaxSuccessiveErrorsExceededError)
      expect(e.cause.message).to eq('Error 4')
    end
  end

  it 'raises an error after too many total failures' do
    monitor = Utility::ErrorMonitor.new(:connector => connector, :max_errors => 5, :max_consecutive_errors => 2)
    expect { add_errors(monitor, 6, :alternate_success => true) }.to raise_error do |e|
      expect(e).to be_a(Utility::ErrorMonitor::MaxErrorsExceededError)
      expect(e.cause.message).to eq('Error 6')
    end
  end

  it 'raises an error after too many failures in a window' do
    monitor = Utility::ErrorMonitor.new(:connector => connector, :max_consecutive_errors => 15)
    expect { add_errors(monitor, 15) }.to_not raise_error
    monitor.note_success
    expect { monitor.note_error(StandardError.new("The hair that broke the camel's back")) }.to raise_error do |e|
      expect(e).to be_a(Utility::ErrorMonitor::MaxErrorsInWindowExceededError)
      expect(e.cause.message).to eq("The hair that broke the camel's back")
    end
  end

  it 'raises an error when finalized even if the window is not full' do
    monitor = Utility::ErrorMonitor.new(:connector => connector)
    expect { add_errors(monitor, 10, :alternate_success => true) }.to_not raise_error
    expect { monitor.finalize }.to raise_error do |e|
      expect(e).to be_a(Utility::ErrorMonitor::MaxErrorsInWindowExceededError)
      expect(e.cause.message).to eq('Error 10')
    end
  end

  it 'stores up to :error_buffer_size last errors' do
    monitor = Utility::ErrorMonitor.new(:connector => connector, :max_consecutive_errors => 15, :error_queue_size => 10)
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

