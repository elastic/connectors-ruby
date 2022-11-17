#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'connectors/base/advanced_snippet_against_schema_validator'
require 'core/filtering/validation_status'

describe Connectors::Base::AdvancedSnippetAgainstSchemaValidator do
  let(:config_schema) {
    {}
  }

  let(:advanced_snippet) {
    {}
  }

  subject { described_class.new(advanced_snippet, config_schema) }

  it_behaves_like 'an advanced snippet validator'

  describe '#is_snippet_valid?' do
    context 'fields constraints are present' do
      let(:constraints) {
        [false]
      }

      let(:config_schema) {
        {
          :fields => {
            :constraints => constraints,
            :values => [
              {
                :name => 'field_one',
                :type => String,
                :optional => true
              },
              {
                :name => 'field_two',
                :type => String,
                :optional => true
              }
            ]
          }
        }
      }

      context 'only one field allowed' do
        context 'constraint is not wrapped in an array' do
          let(:constraints) {
            ->(fields) { fields.size == 1 }
          }

          let(:advanced_snippet) {
            {
              :field_one => 'value one',
              :field_two => 'value two'
            }
          }

          it_behaves_like 'advanced snippet is invalid'
        end

        context 'constraint is wrapped in an array' do
          let(:constraints) {
            [->(fields) { fields.size == 1 }]
          }

          let(:advanced_snippet) {
            {
              :field_one => 'value one',
              :field_two => 'value two'
            }
          }

          it_behaves_like 'advanced snippet is invalid'
        end
      end

      context 'two fields allowed' do
        let(:constraints) {
          [->(fields) { fields.size == 2 }]
        }

        let(:advanced_snippet) {
          {
            :field_one => 'value one',
            :field_two => 'value two'
          }
        }

        it_behaves_like 'advanced snippet is valid'
      end

      context 'two fields are allowed and their key must be equal to their value' do
        let(:constraints) {
          [
            ->(fields) { fields.size == 2 },
            lambda { |fields|
              fields.each { |field_name, field_value|
                return false unless field_name.to_s == field_value
              }
            }
          ]
        }

        context 'the value of the second field is not the same as the field name' do
          let(:advanced_snippet) {
            {
              :field_one => 'field_one',
              :field_two => 'wrong value'
            }
          }

          it_behaves_like 'advanced snippet is invalid'
        end

        context 'both field names equal their value' do
          let(:advanced_snippet) {
            {
              :field_one => 'field_one',
              :field_two => 'field_two'
            }
          }

          it_behaves_like 'advanced snippet is valid'
        end
      end
    end

    context 'max recursion depth exceeded' do
      let(:config_schema) {
        {
          :fields => [
            {
              :name => 'level_one',
              :type => Hash,
              :fields => [
                {
                  :name => 'level_two',
                  :type => Hash,
                  :fields => [
                    {
                      :name => 'level_three',
                      :type => Hash
                    }
                  ]
                }
              ]
            }
          ]
        }
      }

      let(:advanced_snippet) {
        {
          :level_one => {
            :level_two => {
              :level_three => {}
            }
          }
        }
      }

      before(:each) do
        stub_const('Connectors::Base::AdvancedSnippetAgainstSchemaValidator::MAX_RECURSION_DEPTH', 1)
      end

      it 'stops logs warning' do
        allow(Utility::Logger).to receive(:warn)
        expect(Utility::Logger).to receive(:warn).with(include('Recursion depth for filtering validation exceeded'))

        subject.is_snippet_valid?
      end

      it_behaves_like 'advanced snippet is invalid'
    end

    context 'config schema is empty' do
      context 'config schema is empty hash' do
        let(:config_schema) {
          {}
        }

        it_behaves_like 'advanced snippet is valid'
      end

      context 'config schema is nil' do
        let(:config_schema) {
          nil
        }

        it_behaves_like 'advanced snippet is valid'
      end
    end

    context 'config schema is not empty' do
      context 'config schema expects one field as string' do
        let(:config_schema) {
          {
            :fields => [
              {
                :name => 'field',
                :type => String
              }
            ]
          }
        }

        context 'advanced snippet contains a string' do
          context 'field has correct name and correct type' do
            context 'field key is a string' do
              let(:advanced_snippet) {
                {
                  'field' => 'a string'
                }
              }

              it_behaves_like 'advanced snippet is valid'
            end

            context 'field key is a symbol' do
              let(:advanced_snippet) {
                {
                  :field => 'a string'
                }
              }

              it_behaves_like 'advanced snippet is valid'
            end
          end

          context 'field has correct name, but wrong type' do
            let(:advanced_snippet) {
              {
                'field' => { :value => 'a string' }
              }
            }

            it_behaves_like 'advanced snippet is invalid'
          end

          context 'field has wrong name, but correct type' do
            let(:advanced_snippet) {
              {
                'wrong name' => 'a string'
              }
            }

            it_behaves_like 'advanced snippet is invalid'
          end

          context 'field has wrong name and wrong type' do
            let(:advanced_snippet) {
              {
                'wrong name' => [1, 2, 3]
              }
            }

            it_behaves_like 'advanced snippet is invalid'
          end
        end
      end

      context 'config schema contains custom type matcher function' do
        let(:config_schema) {
          {
            :fields => [
              {
                :name => 'field_with_custom_type',
                :type => ->(field_value) { field_value.is_a?(Array) && field_value.include?('A') }
              }
            ]
          }
        }

        context 'advanced snippet contains array with \'A\'' do
          let(:advanced_snippet) {
            {
              :field_with_custom_type => %w[A B C]
            }
          }

          it_behaves_like 'advanced snippet is valid'
        end

        context 'advanced snippet does not contain array with \'A\'' do
          let(:advanced_snippet) {
            {
              :field_with_custom_type => %w[B C]
            }
          }

          it_behaves_like 'advanced snippet is invalid'
        end
      end

      context 'config schema expects three fields with different types and one optional' do
        let(:config_schema) {
          {
            :fields => [
              {
                :name => 'field_one',
                :type => String
              },
              {
                :name => 'field_two',
                :type => Integer
              },
              {
                :name => 'field_three',
                :type => Hash,
                :optional => true
              }
            ]
          }
        }

        context 'all names and types are correct' do
          let(:advanced_snippet) {
            {
              'field_one' => 'a string',
              :field_two => 1,
              'field_three' => { :value => 'value' }
            }
          }

          it_behaves_like 'advanced snippet is valid'
        end

        context 'one name is wrong' do
          let(:advanced_snippet) {
            {
              'wrong_name' => 'a string',
              :field_two => 1,
              'field_three' => { :value => 'value' }
            }
          }

          it_behaves_like 'advanced snippet is invalid'
        end

        context 'one type is wrong' do
          let(:advanced_snippet) {
            {
              'field_one' => 'a string',
              :field_two => 'I should be an Integer',
              'field_three' => { :value => 'value' }
            }
          }

          it_behaves_like 'advanced snippet is invalid'
        end

        context 'one field is missing' do
          context 'other fields are valid' do
            let(:advanced_snippet) {
              {
                'field_one' => 'a string',
                :field_two => 1,
              }
            }

            it_behaves_like 'advanced snippet is valid'
          end
        end

        context 'advanced snippet is empty' do
          context 'advanced snippet is nil' do
            let(:advanced_snippet) {
              nil
            }

            it_behaves_like 'advanced snippet is invalid'
          end

          context 'advanced snippet is empty hash' do
            let(:advanced_snippet) {
              {}
            }

            it_behaves_like 'advanced snippet is invalid'
          end
        end
      end

      context 'config schema contains deeply nested fields' do
        let(:config_schema) {
          {
          :fields => [
            {
              :name => 'level_one',
              :type => Hash,
              :fields => [
                {
                  :name => 'level_two',
                  :type => Hash,
                  :fields => [
                    {
                      :name => 'level_three',
                      :type => Hash,
                      :fields => [
                        {
                          :name => 'field_one',
                          :type => String
                        },
                        {
                          :name => 'field_two',
                          :type => Integer,
                          :optional => true
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
          }
        }

        context 'advanced snippet is valid' do
          context 'advanced snippet only contains symbols as keys' do
            let(:advanced_snippet) {
              {
                :level_one => {
                  :level_two => {
                    :level_three => {
                      :field_one => 'Value',
                      :field_two => 1
                    }
                  }
                }
              }
            }

            it_behaves_like 'advanced snippet is valid'
          end

          context 'advanced snippet only contains strings as keys' do
            let(:advanced_snippet) {
              {
                'level_one' => {
                  'level_two' => {
                    'level_three' => {
                      'field_one' => 'Value',
                      'field_two' => 1
                    }
                  }
                }
              }
            }

            it_behaves_like 'advanced snippet is valid'
          end

          context 'advanced snippet contains string and symbols as keys' do
            let(:advanced_snippet) {
              {
                'level_one' => {
                  :level_two => {
                    'level_three' => {
                      :field_one => 'Value',
                      'field_two' => 1
                    }
                  }
                }
              }
            }

            it_behaves_like 'advanced snippet is valid'
          end

          context 'advanced snippet does not contain optional field' do
            let(:advanced_snippet) {
              {
                :level_one => {
                  :level_two => {
                    :level_three => {
                      :field_one => 'Value'
                    }
                  }
                }
              }
            }

            it_behaves_like 'advanced snippet is valid'
          end
        end

        context 'level one' do
          context 'is missing' do
            let(:advanced_snippet) {
              {
                :level_one => nil
              }
            }

            it_behaves_like 'advanced snippet is invalid'
          end

          context 'has wrong type' do
            let(:advanced_snippet) {
              {
                :level_one => 'wrong type'
              }
            }

            it_behaves_like 'advanced snippet is invalid'
          end
        end

        context 'level two' do
          context 'is missing' do
            let(:advanced_snippet) {
              {
                :level_one => {
                  :level_two => nil
                }
              }
            }

            it_behaves_like 'advanced snippet is invalid'
          end

          context 'has wrong type' do
            let(:advanced_snippet) {
              {
                :level_one => {
                  :level_two => 'wrong type'
                }
              }
            }

            it_behaves_like 'advanced snippet is invalid'
          end
        end

        context 'level three' do
          context 'is missing' do
            let(:advanced_snippet) {
              {
                :level_one => {
                  :level_two => {
                    :level_three => nil
                  }
                }
              }
            }

            it_behaves_like 'advanced snippet is invalid'
          end

          context 'has wrong type' do
            let(:advanced_snippet) {
              {
                :level_one => {
                  :level_two => {
                    :level_three => 'wrong type'
                  }
                }
              }
            }

            it_behaves_like 'advanced snippet is invalid'
          end
        end

        context 'field_one' do
          context 'is missing' do
            let(:advanced_snippet) {
              {
                :level_one => {
                  :level_two => {
                    :level_three => {
                      # optional field present, but mandatory missing
                      :field_two => 1
                    }
                  }
                }
              }
            }

            it_behaves_like 'advanced snippet is invalid'
          end

          context 'has wrong type' do
            let(:advanced_snippet) {
              {
                :level_one => {
                  :level_two => {
                    :level_three => {
                      # wrong type
                      :field_one => 1
                    }
                  }
                }
              }
            }

            it_behaves_like 'advanced snippet is invalid'
          end
        end
      end
    end
  end
end
