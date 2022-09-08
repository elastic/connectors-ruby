# frozen_string_literal: true

#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'fugit'
require 'spec_helper'
require 'utility/cron'

# see http://www.quartz-scheduler.org/documentation/quartz-2.3.0/tutorials/crontrigger.html
RSpec.describe Utility::Cron do
  it 'supports various expressions' do
    conversions = [
      ['0 15 10 * * ? 2005', '15 10 * * *'],
      ['0 0 12 * * ?', '0 12 * * *'],
      ['0 15 10 ? * *', '15 10 * * *'],
      ['0 15 10 * * ?', '15 10 * * *'],
      ['0 15 10 * * ? *', '15 10 * * *'],
      ['0 15 10 * * ? 2005', '15 10 * * *'],
      ['0 * 14 * * ?', '* 14 * * *'],
      ['0 0/5 14 * * ?', '0/5 14 * * *'],
      ['0 0/5 14,18 * * ?', '0/5 14,18 * * *'],
      ['0 0-5 14 * * ?', '0-5 14 * * *'],
      ['0 10,44 14 ? 3 WED', '10,44 14 * 3 WED'],
      ['0 15 10 ? * MON-FRI', '15 10 * * MON-FRI'],
      ['0 15 10 15 * ?', '15 10 15 * *'],
      ['0 0 12 1/5 * ?', '0 12 1/5 * *'],
      ['0 11 11 11 11 ?', '11 11 11 11 *'],
      ['0 20 6 ? * 5', '20 6 * * 4'], # every Thursday at 6:20 AM
      ['0 0 12 ? * 2', '0 12 * * 1'], # every Monday at 12:00 PM
      ['0 0 0 ? * 7', '0 0 * * 6'], # every Saturday at 12:00 AM
      ['0 0 0 ? * 0', '0 0 * * 0'], # every Sunday at 12:00 AM
    ]

    conversions.each do |quartz, crontab|
      expect(subject.quartz_to_crontab(quartz)).to eq(crontab)
      next_time = Fugit::Cron.do_parse(crontab).next_time
      print "### next_time for scheduler [#{quartz}], cron [#{crontab}]: [#{next_time}]\n"
      expect(next_time).to be > Time.now
    end

    unsupported = ['0 15 10 ? * 6#3', '0 15 10 L * ?',
                   '0 15 10 L-2 * ?',
                   '0 15 10 ? * 6L',
                   '0 15 10 ? * 6L 2002-2005',
                   '0 15 10 ? * 6#3']

    unsupported.each do |quartz|
      expect { subject.quartz_to_crontab(quartz) }.to raise_error(Exception)
    end
  end
end
