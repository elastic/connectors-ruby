#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core'
require 'utility/logger'

module Core
  class JobCleanUp
    class << self
      def execute(connector_id = nil)
        process_orphaned_jobs
        process_stuck_jobs(connector_id)
      end

      private

      def process_orphaned_jobs
        Utility::Logger.debug('Start cleaning up orphaned jobs...')
        all_connectors = ConnectorSettings.fetch_all_connectors
        orphaned_jobs = ConnectorJob.orphaned_jobs(all_connectors.map(&:id))
        if orphaned_jobs.empty?
          Utility::Logger.debug('No orphaned jobs found. Skipping...')
          return
        end

        # delete content indicies in case they are re-created by sync job
        content_indices = (orphaned_jobs.map(&:index_name) - all_connectors.map(&:index_name)).compact.uniq
        ElasticConnectorActions.delete_indices(content_indices) if content_indices.any?
        result = ConnectorJob.delete_jobs(orphaned_jobs)
        Utility::Logger.error("Error found when deleting jobs: #{result['failures']}") if result['failures']&.any?
        Utility::Logger.info("Successfully deleted #{result['deleted']} out of #{result['total']} orphaned jobs.")
      end

      def process_stuck_jobs(connector_id = nil)
        Utility::Logger.debug("Start cleaning up stuck jobs for #{connector_id ? "connector #{connector_id}" : 'native connectors'}...")
        stuck_jobs = ConnectorJob.stuck_jobs(connector_id)
        if stuck_jobs.empty?
          Utility::Logger.debug('No stuck jobs found. Skipping...')
          return
        end

        marked_count = 0
        stuck_jobs.each do |job|
          job.error!('The job has not seen any update for some time.')
          Utility::Logger.debug("Successfully marked job #{job.id} as error.")

          job_id = job.id
          job = ConnectorJob.fetch_by_id(job_id)
          Utility::Logger.warn("Could not found job by id #{job_id}") if job.nil?
          Utility::Logger.warn("Could not found connector by id #{job.connector_id}") if job && job.connector.nil?

          job&.connector&.update_last_sync!(job)
          marked_count += 1
        rescue StandardError => e
          Utility::ExceptionTracking.log_exception(e)
        end
        Utility::Logger.info("Successfully marked #{marked_count} out of #{stuck_jobs.count} stuck jobs as error.")
      end
    end
  end
end
