#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'connectors/mongodb/mongo_advanced_snippet_against_schema_validator'
require 'connectors/mongodb/mongo_advanced_snippet_schema'
require 'core/filtering/validation_status'

describe Connectors::MongoDB::MongoAdvancedSnippetAgainstSchemaValidator do
  let(:advanced_snippet) {
    {}
  }

  subject { described_class.new(advanced_snippet) }

  describe '#is_snippet_valid?' do
    context 'advanced snippet is not present' do
      context 'advanced snippet is nil' do
        let(:advanced_snippet) {
          nil
        }

        it_behaves_like 'advanced snippet is valid'
      end

      context 'advanced snippet is empty' do
        let(:advanced_snippet) {
          {}
        }

        it_behaves_like 'advanced snippet is valid'
      end
    end

    context 'aggregate and find present' do
      let(:advanced_snippet) {
        {
          :aggregate => {},
          :find => {}
        }
      }

      it_behaves_like 'advanced snippet is invalid'
    end

    context 'find' do
      context 'find is not present' do
        context 'find is nil' do
          let(:advanced_snippet) {
            {
              :find => nil
            }
          }

          it_behaves_like 'advanced snippet is valid'
        end

        context 'find is empty' do
          let(:advanced_snippet) {
            {
              :find => {}
            }
          }

          it_behaves_like 'advanced snippet is valid'
        end
      end

      context 'filter is not present' do
        context 'filter is nil' do
          let(:advanced_snippet) {
            {
              :find => {
                :filter => nil
              }
            }
          }

          it_behaves_like 'advanced snippet is valid'
        end

        context 'filter is empty' do
          let(:advanced_snippet) {
            {
              :find => {
                :filter => {}
              }
            }
          }

          it_behaves_like 'advanced snippet is valid'
        end
      end

      context 'options are not present' do
        context 'options are nil' do
          let(:advanced_snippet) {
            {
              :find => {
                :options => nil
              }
            }
          }

          it_behaves_like 'advanced snippet is valid'
        end

        context 'options are empty' do
          let(:advanced_snippet) {
            {
              :find => {
                :options => {}
              }
            }
          }

          it_behaves_like 'advanced snippet is valid'
        end
      end

      context 'filter and options are empty' do
        let(:advanced_snippet) {
          {
            :find => {
              :filter => {},
              :options => {}
            }
          }
        }

        it_behaves_like 'advanced snippet is valid'
      end
    end

    context 'aggregate' do
      context 'options' do
        context 'snippet with every option' do
          let(:advanced_snippet) {
            {
              :aggregate => {
                :options => {
                  :explain => true,
                  :allowDiskUse => false,
                  :cursor => { :batchSize => 5 },
                  :maxTimeMS => 10,
                  :bypassDocumentValidation => false,
                  :readConcern => {
                    :level => 'local'
                  },
                  :collation => {
                    :locale => 'en_EN',
                    :caseLevel => true,
                    :caseFirst => 'case first',
                    :strength => 5,
                    :numericOrdering => true,
                    :alternate => 'alternative',
                    :maxVariable => 'some value',
                    :backwards => true
                  },
                  :hint => 'some hint',
                  :comment => 'comment',
                  :writeConcern => {},
                  :let => { :variable_one => 'value' }
                }
              }
            }
          }

          it_behaves_like 'advanced snippet is valid'
        end

        context 'hint' do
          let(:hint) {}

          let(:advanced_snippet) {
            {
              :aggregate => {
                :options => {
                  :hint => hint
                }
              }
            }
          }

          context 'is a string' do
            let(:hint) {
              'hint'
            }

            it_behaves_like 'advanced snippet is valid'
          end

          context 'is a document' do
            let(:hint) {
              {
                :value => 'hint'
              }
            }

            it_behaves_like 'advanced snippet is valid'
          end
        end

        context 'maxTimeMS' do
          let(:maxTimeMS) {}

          let(:advanced_snippet) {
            {
              :aggregate => {
                :options => {
                  :maxTimeMS => maxTimeMS
                }
              }
            }
          }

          context 'is 0' do
            let(:maxTimeMS) {
              0
            }

            it_behaves_like 'advanced snippet is valid'
          end

          context 'is 100' do
            let(:maxTimeMS) {
              100
            }

            it_behaves_like 'advanced snippet is valid'
          end
        end

        context 'readConcernLevel' do
          let(:readConcernLevel) {}

          let(:advanced_snippet) {
            {
              :aggregate => {
                :options => {
                  :readConcern => {
                    :level => readConcernLevel
                  }
                }
              }
            }
          }

          context 'is local' do
            let(:readConcernLevel) {
              'local'
            }

            it_behaves_like 'advanced snippet is valid'
          end

          context 'is available' do
            let(:readConcernLevel) {
              'available'
            }

            it_behaves_like 'advanced snippet is valid'
          end

          context 'is majority' do
            let(:readConcernLevel) {
              'majority'
            }

            it_behaves_like 'advanced snippet is valid'
          end

          context 'is linearizable' do
            let(:readConcernLevel) {
              'linearizable'
            }

            it_behaves_like 'advanced snippet is valid'
          end
        end

        context 'invalid snippet' do
          context 'snippet with wrong key' do
            let(:advanced_snippet) {
              {
                :aggregate => {
                  :options => {
                    :wrong_key => {

                    }
                  }
                }
              }
            }

            it_behaves_like 'advanced snippet is invalid'
          end

          context 'maxTimeMS' do
            let(:maxTimeMS) {}

            let(:advanced_snippet) {
              {
                :aggregate => {
                  :options => {
                    :maxTimeMS => maxTimeMS
                  }
                }
              }
            }

            context 'is -10' do
              let(:maxTimeMS) {
                -10
              }

              it_behaves_like 'advanced snippet is invalid'
            end
          end

          context 'readConcernLevel' do
            let(:readConcernLevel) {}

            let(:advanced_snippet) {
              {
                :aggregate => {
                  :options => {
                    :readConcern => {
                      :level => readConcernLevel
                    }
                  }
                }
              }
            }

            context 'is wrong value' do
              let(:readConcernLevel) {
                'wrong value'
              }

              it_behaves_like 'advanced snippet is invalid'
            end
          end
        end
      end

      context 'pipeline' do
        context 'with all stages' do
          let(:advanced_snippet) {
            {
              :aggregate => {
                :pipeline => [
                  { :$addFields => {} },
                  { :$bucket => {} },
                  { :$bucketAuto => {} },
                  { :$changeStream => {} },
                  { :$collStats => {} },
                  { :$count => {} },
                  { :$densify => {} },
                  { :$documents => {} },
                  { :$facet => {} },
                  { :$fill => {} },
                  { :$geoNear => {} },
                  { :$graphLookup => {} },
                  { :$group => {} },
                  { :$indexStats => {} },
                  { :$limit => {} },
                  { :$listSessions => {} },
                  { :$lookup => {} },
                  { :$match => {} },
                  { :$merge => {} },
                  { :$out => {} },
                  { :$planCacheStats => {} },
                  { :$project => {} },
                  { :$redact => {} },
                  { :$replaceRoot => {} },
                  { :$replaceWith => {} },
                  { :$sample => {} },
                  { :$search => {} },
                  { :$searchMeta => {} },
                  { :$set => {} },
                  { :$setWindowFields => {} },
                  { :$skip => {} },
                  { :$sort => {} },
                  { :$sortByCount => {} },
                  { :$unionWith => {} },
                  { :$unset => {} },
                  { :$unwind => {} },
                ]
              }
            }
          }

          it_behaves_like 'advanced snippet is valid'
        end

        context '$addFields appears multiple times' do
          let(:advanced_snippet) {
            {
              :aggregate => {
                :pipeline => [
                  { :$addFields => {} },
                  { :$addFields => {} },
                  { :$addFields => {} }
                ]
              }
            }
          }

          it_behaves_like 'advanced snippet is valid'
        end

        context '$out appears multiple times' do
          let(:advanced_snippet) {
            {
              :aggregate => {
                :pipeline => [
                  { :$out => {} },
                  { :$out => {} }
                ]
              }
            }
          }

          it_behaves_like 'advanced snippet is invalid'
        end

        context '$merge appears multiple times' do
          let(:advanced_snippet) {
            {
              :aggregate => {
                :pipeline => [
                  { :$merge => {} },
                  { :$merge => {} }
                ]
              }
            }
          }

          it_behaves_like 'advanced snippet is invalid'
        end

        context '$geoNear appears multiple times' do
          let(:advanced_snippet) {
            {
              :aggregate => {
                :pipeline => [
                  { :$geoNear => {} },
                  { :$geoNear => {} }
                ]
              }
            }
          }

          it_behaves_like 'advanced snippet is invalid'
        end

        context '$changeStream appears multiple times' do
          let(:advanced_snippet) {
            {
              :aggregate => {
                :pipeline => [
                  { :$changeStream => {} },
                  { :$changeStream => {} }
                ]
              }
            }
          }

          it_behaves_like 'advanced snippet is invalid'
        end

        context 'with one valid stage' do
          let(:advanced_snippet) {
            {
              :aggregate => {
                :pipeline => [
                  { :$addFields => {} }
                ]
              }
            }
          }

          it_behaves_like 'advanced snippet is valid'
        end

        context 'without a stage' do
          let(:advanced_snippet) {
            {
              :aggregate => {
                :pipeline => []
              }
            }
          }

          it_behaves_like 'advanced snippet is valid'
        end

        context 'with invalid stages' do
          let(:advanced_snippet) {
            {
              :aggregate => {
                :pipeline => [
                  { :wrong_stage => {} },
                  { :another_wrong_stage => {} },
                ]
              }
            }
          }

          it_behaves_like 'advanced snippet is invalid'
        end
      end
    end
  end
end
