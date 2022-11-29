#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Connectors
  module MongoDB
    module AdvancedSnippet
      # Pipeline stages: https://www.mongodb.com/docs/manual/reference/operator/aggregation-pipeline/
      ALLOWED_PIPELINE_STAGES = %w[
        $addFields $bucket $bucketAuto $changeStream $collStats $count $densify
        $documents $facet $fill $geoNear $graphLookup $group $indexStats $limit
        $listSessions $lookup $match $merge $out $planCacheStats $project $redact
        $replaceRoot $replaceWith $sample $search $searchMeta $set $setWindowFields
        $skip $sort $sortByCount $unionWith $unset $unwind
      ]

      # All except the $out, $merge, $geoNear, and $changeStream stages can appear multiple times in a pipeline.
      # Source: https://www.mongodb.com/docs/manual/reference/operator/aggregation-pipeline/
      PIPELINE_STAGES_ALLOWED_ONCE = %w[$out $merge $geoNear $changeStream]

      NON_NEGATIVE_INTEGER = ->(value) { value.is_a?(Integer) && value >= 0 }
      READ_CONCERN_LEVEL = ->(level) { %w[local available majority linearizable].include?(level) }
      STRING_OR_DOCUMENT = ->(value) { value.is_a?(Hash) || value.is_a?(String) }
      MUTUAL_EXCLUSIVE_FILTER = ->(fields) { fields.nil? || fields.size <= 1 }

      AGGREGATION_PIPELINE = lambda { |pipeline|
        return false unless pipeline.is_a?(Array)

        allowed_once_appearances = Set.new

        pipeline.flat_map(&:keys).each do |key|
          return false unless ALLOWED_PIPELINE_STAGES.include?(key)

          if PIPELINE_STAGES_ALLOWED_ONCE.include?(key)
            return false if allowed_once_appearances.include?(key)

            allowed_once_appearances.add(key)
          end
        end

        true
      }

      # Ruby has no 'Boolean' class
      BOOLEAN = ->(value) { value.is_a?(TrueClass) || value.is_a?(FalseClass) }

      COLLATION = {
        :name => 'collation',
        :type => Hash,
        :optional => true,
        :fields => [
          {
            :name => 'locale',
            :type => String,
            :optional => true
          },
          {
            :name => 'caseLevel',
            :type => BOOLEAN,
            :optional => true
          },
          {
            :name => 'caseFirst',
            :type => String,
            :optional => true
          },
          {
            :name => 'strength',
            :type => Integer,
            :optional => true
          },
          {
            :name => 'numericOrdering',
            :type => BOOLEAN,
            :optional => true
          },
          {
            :name => 'alternate',
            :type => String,
            :optional => true
          },
          {
            :name => 'maxVariable',
            :type => String,
            :optional => true
          },
          {
            :name => 'backwards',
            :type => BOOLEAN,
            :optional => true
          },
        ]
      }

      CURSOR_TYPE = ->(cursor) { [:tailable, :tailable_await].include?(cursor) }

      # Aggregate options: https://www.mongodb.com/docs/manual/reference/method/db.collection.aggregate/
      AGGREGATE_OPTIONS = {
        :name => 'options',
        :type => Hash,
        :optional => true,
        :fields => [
          {
            :name => 'explain',
            :type => BOOLEAN,
            :optional => true
          },
          {
            :name => 'allowDiskUse',
            :type => BOOLEAN,
            :optional => true
          },
          {
            :name => 'cursor',
            :type => Hash,
            :optional => true,
            :fields => [
              {
                :name => 'batchSize',
                :type => NON_NEGATIVE_INTEGER
              }
            ]
          },
          {
            :name => 'maxTimeMS',
            :type => NON_NEGATIVE_INTEGER,
            :optional => true
          },
          {
            :name => 'bypassDocumentValidation',
            :type => BOOLEAN,
            :optional => true
          },
          {
            :name => 'readConcern',
            :type => Hash,
            :optional => true,
            :fields => [
              {
                :name => 'level',
                :type => READ_CONCERN_LEVEL
              }
            ]
          },
          COLLATION,
          {
            :name => 'hint',
            :type => STRING_OR_DOCUMENT,
            :optional => true
          },
          {
            :name => 'comment',
            :type => String,
            :optional => true
          },
          {
            :name => 'writeConcern',
            :type => Hash,
            :optional => true
          },
          {
            :name => 'let',
            :type => Hash,
            :optional => true
          }
        ]
      }

      AGGREGATE_PIPELINE = {
        :name => 'pipeline',
        :type => AGGREGATION_PIPELINE,
        :optional => true,
      }

      AGGREGATE = {
        :name => 'aggregate',
        :type => Hash,
        :optional => true,
        :fields => [
          AGGREGATE_PIPELINE,
          AGGREGATE_OPTIONS
        ]
      }

      FIND_OPTIONS = {
        :name => 'options',
        :type => Hash,
        :optional => true,
        :fields => [
          {
            :name => 'allowDiskUse',
            :type => BOOLEAN,
            :optional => true
          },
          {
            :name => 'allowPartialResults',
            :type => BOOLEAN,
            :optional => true
          },
          {
            :name => 'batchSize',
            :type => NON_NEGATIVE_INTEGER,
            :optional => true
          },
          COLLATION,
          {
            :name => 'cursorType',
            :type => CURSOR_TYPE,
            :optional => true
          },
          {
            :name => 'limit',
            :type => NON_NEGATIVE_INTEGER,
            :optional => true
          },
          {
            :name => 'maxTimeMS',
            :type => NON_NEGATIVE_INTEGER,
            :optional => true
          },
          {
            :name => 'modifiers',
            :type => Hash,
            :optional => true
          },
          {
            :name => 'noCursorTimeout',
            :type => BOOLEAN,
            :optional => true
          },
          {
            :name => 'oplogReplay',
            :type => BOOLEAN,
            :optional => true
          },
          {
            :name => 'projection',
            :type => Hash,
            :optional => true
          },
          {
            :name => 'skip',
            :type => NON_NEGATIVE_INTEGER,
            :optional => true
          },
          {
            :name => 'sort',
            :type => Hash,
            :optional => true
          },
          {
            :name => 'let',
            :type => Hash,
            :optional => true
          }
        ]
      }

      # TODO: return true for now. Will be more involved (basically needs full query parsing or "dummy" execution against a running instance)
      FILTER = ->(_filter) { true }

      FIND_FILTER = {
        :name => 'filter',
        :type => FILTER
      }

      FIND = {
        :name => 'find',
        :type => Hash,
        :optional => true,
        :fields => [
          FIND_OPTIONS,
          FIND_FILTER
        ]
      }

      SCHEMA = {
        :fields => {
          :constraints => MUTUAL_EXCLUSIVE_FILTER,
          :values => [
            AGGREGATE,
            FIND
          ]
        }
      }
    end
  end
end
