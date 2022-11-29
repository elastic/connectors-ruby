#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'core/filtering/filter_validator'

describe Core::Filtering::FilterValidator do
  let(:invalid_filtering_validation_result) {
    { :state => Core::Filtering::ValidationStatus::INVALID, :errors => [{ :ids => ['error-id'], :messages => ['error message'] }] }
  }

  let(:valid_filtering_validation_result) {
    { :state => Core::Filtering::ValidationStatus::VALID, :errors => [] }
  }

  let(:snippet_validator_one_class) { double }
  let(:snippet_validator_one_instance) { double }

  let(:snippet_validator_two_class) { double }
  let(:snippet_validator_two_instance) { double }

  let(:snippet_validators_classes) {
    [
      snippet_validator_one_class,
      snippet_validator_two_class
    ]
  }

  let(:rule_validator_one_class) { double }
  let(:rule_validator_one_instance) { double }

  let(:rule_validator_two_class) { double }
  let(:rule_validator_two_instance) { double }

  let(:rules_validator_classes) {
    [
      rule_validator_one_class,
      rule_validator_two_class
    ]
  }

  let(:rules_pre_processing_active) {
    false
  }

  let(:filtering) {
    {}
  }

  let(:validation_result) {
    nil
  }

  subject {
    described_class.new(snippet_validator_classes: snippet_validators_classes,
                        rules_validator_classes: rules_validator_classes,
                        rules_pre_processing_active: rules_pre_processing_active)
  }

  shared_examples_for 'filtering is valid' do
    it '' do
      validation_result = subject.is_filter_valid(filtering)

      expect(validation_result[:state]).to eq(Core::Filtering::ValidationStatus::VALID)
      expect(validation_result[:errors]).to be_empty
    end
  end

  shared_examples_for 'filtering is invalid' do
    it '' do
      validation_result = subject.is_filter_valid(filtering)

      expect(validation_result[:state]).to eq(Core::Filtering::ValidationStatus::INVALID)
      expect(validation_result[:errors]).to_not be_empty
      expect(validation_result[:errors]).to be_an(Array)
    end
  end

  shared_examples_for 'logs a warning' do |times|
    it '' do
      times ||= 1

      expect(Utility::Logger).to receive(:warn).exactly(times).times

      subject.is_filter_valid(filtering)
    end
  end

  describe '#is_filter_valid' do
    before(:each) {
      allow(rule_validator_one_class).to receive(:new).and_return(rule_validator_one_instance)
      allow(rule_validator_two_class).to receive(:new).and_return(rule_validator_two_instance)

      allow(snippet_validator_one_class).to receive(:new).and_return(snippet_validator_one_instance)
      allow(snippet_validator_two_class).to receive(:new).and_return(snippet_validator_two_instance)
    }

    context 'when filter is not present' do
      # We don't validate filtering, if it's not present -> just return valid

      context 'filtering is nil' do
        let(:filtering) {
          nil
        }

        it_behaves_like 'filtering is valid'
      end

      context 'filtering is an empty array' do
        let(:filtering) {
          []
        }

        it_behaves_like 'filtering is valid'
      end

      context 'filtering is an empty hash' do
        let(:filtering) {
          {}
        }

        it_behaves_like 'filtering is valid'
      end
    end

    context 'when filter is present' do
      let(:filtering) {
        {
          'advanced_snippet' => {},
          'rules' => []
        }
      }

      context 'when every validator returns valid' do
        before do
          allow(rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
          allow(rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)

          allow(snippet_validator_one_instance).to receive(:is_snippet_valid).and_return(valid_filtering_validation_result)
          allow(snippet_validator_two_instance).to receive(:is_snippet_valid).and_return(valid_filtering_validation_result)
        end

        it_behaves_like 'filtering is valid'

        it 'returns one valid result' do
          validation_result = subject.is_filter_valid(filtering)

          expect(validation_result).to match(valid_filtering_validation_result)
        end
      end

      context 'when the first rule validator returns invalid' do
        let(:invalid_filtering_validation_result) {
          {
            :state => Core::Filtering::ValidationStatus::INVALID,
            :errors => [
              {
                :ids => ['simple-rules'],
                :messages => ['error message']
              }
            ]
          }
        }

        before do
          allow(rule_validator_one_instance).to receive(:are_rules_valid).and_return(invalid_filtering_validation_result)
          allow(rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)

          allow(snippet_validator_one_instance).to receive(:is_snippet_valid).and_return(valid_filtering_validation_result)
          allow(snippet_validator_two_instance).to receive(:is_snippet_valid).and_return(valid_filtering_validation_result)
        end

        it_behaves_like 'filtering is invalid'

        it_behaves_like 'logs a warning'

        it 'returns one error related to rules in the merged result' do
          validation_result = subject.is_filter_valid(filtering)

          expect(validation_result[:errors]).to match([{ :ids => ['simple-rules'], :messages => ['error message'] }])
        end
      end

      context 'when the second advanced snippet validator returns invalid' do
        let(:invalid_filtering_validation_result) {
          {
            :state => Core::Filtering::ValidationStatus::INVALID,
            :errors => [
              {
                :ids => ['advanced-snippet'],
                :messages => ['error message']
              }
            ]
          }
        }

        before do
          allow(rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
          allow(rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)

          allow(snippet_validator_one_instance).to receive(:is_snippet_valid).and_return(valid_filtering_validation_result)
          allow(snippet_validator_two_instance).to receive(:is_snippet_valid).and_return(invalid_filtering_validation_result)
        end

        it_behaves_like 'filtering is invalid'

        it_behaves_like 'logs a warning'

        it 'returns one error related to advanced snippet in the merged result' do
          validation_result = subject.is_filter_valid(filtering)

          expect(validation_result[:errors]).to match([{ :ids => ['advanced-snippet'], :messages => ['error message'] }])
        end
      end

      context 'when all four validators return invalid results' do
        let(:invalid_snippet_validation_result_one) {
          {
            :state => Core::Filtering::ValidationStatus::INVALID,
            :errors => [
              {
                :ids => ['advanced-snippet'],
                :messages => ['error-message-snippet-one']
              }
            ]
          }
        }

        let(:invalid_snippet_validation_result_two) {
          {
            :state => Core::Filtering::ValidationStatus::INVALID,
            :errors => [
              {
                :ids => ['advanced-snippet'],
                :messages => ['error-message-snippet-two']
              }
            ]
          }
        }

        let(:invalid_rules_validation_result_one) {
          {
            :state => Core::Filtering::ValidationStatus::INVALID,
            :errors => [
              {
                :ids => ['simple-rules'],
                :messages => ['error-message-rules-one']
              }
            ]
          }
        }

        let(:invalid_rules_validation_result_two) {
          {
            :state => Core::Filtering::ValidationStatus::INVALID,
            :errors => [
              {
                :ids => ['simple-rules'],
                :messages => ['error message-snippet-one']
              }
            ]
          }
        }

        four_times = 4

        before do
          allow(rule_validator_one_instance).to receive(:are_rules_valid).and_return(invalid_rules_validation_result_one)
          allow(rule_validator_two_instance).to receive(:are_rules_valid).and_return(invalid_rules_validation_result_two)

          allow(snippet_validator_one_instance).to receive(:is_snippet_valid).and_return(invalid_snippet_validation_result_one)
          allow(snippet_validator_two_instance).to receive(:is_snippet_valid).and_return(invalid_snippet_validation_result_two)
        end

        it_behaves_like 'filtering is invalid'

        it_behaves_like 'logs a warning', four_times

        it 'returns four errors, two related to advanced snippet and two related to simple rules' do
          validation_result = subject.is_filter_valid(filtering)

          expect(validation_result[:errors]).to include(*invalid_snippet_validation_result_one[:errors],
                                                        *invalid_snippet_validation_result_one[:errors],
                                                        *invalid_snippet_validation_result_one[:errors],
                                                        *invalid_snippet_validation_result_one[:errors])
        end
      end

      context 'when simple rules validators are present in different stages' do
        let(:rules_pre_processing_active) {
          true
        }

        # no snippet validation
        let(:snippet_validators_classes) {
          []
        }

        let(:pre_processing_rule_validator_one_class) { double }
        let(:pre_processing_rule_validator_one_instance) { double }

        let(:pre_processing_rule_validator_two_class) { double }
        let(:pre_processing_rule_validator_two_instance) { double }

        let(:post_processing_rule_validator_one_class) { double }
        let(:post_processing_rule_validator_one_instance) { double }

        let(:post_processing_rule_validator_two_class) { double }
        let(:post_processing_rule_validator_two_instance) { double }

        before do
          allow(pre_processing_rule_validator_one_class).to receive(:new).and_return(pre_processing_rule_validator_one_instance)
          allow(pre_processing_rule_validator_two_class).to receive(:new).and_return(pre_processing_rule_validator_two_instance)

          allow(post_processing_rule_validator_one_class).to receive(:new).and_return(post_processing_rule_validator_one_instance)
          allow(post_processing_rule_validator_two_class).to receive(:new).and_return(post_processing_rule_validator_two_instance)
        end

        context 'when only common rule validators are present' do
          let(:rules_validator_classes) {
            {
              Core::Filtering::ProcessingStage::ALL => [
                rule_validator_one_class,
                rule_validator_two_class
              ]
            }
          }

          context 'when all common validators return valid' do
            before do
              allow(rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
              allow(rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
            end

            it_behaves_like 'filtering is valid'
          end

          context 'when one common validator returns invalid' do
            before do
              allow(rule_validator_one_instance).to receive(:are_rules_valid).and_return(invalid_filtering_validation_result)
              allow(rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
            end

            it_behaves_like 'filtering is invalid'

            it_behaves_like 'logs a warning'
          end
        end

        context 'when pre-processing validators are present' do
          let(:rules_validator_classes) {
            {
              Core::Filtering::ProcessingStage::PRE => [
                pre_processing_rule_validator_one_class,
                pre_processing_rule_validator_two_class
              ]
            }
          }

          context 'when both pre-processing validators return valid' do
            before do
              allow(pre_processing_rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
              allow(pre_processing_rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
            end

            it_behaves_like 'filtering is valid'
          end

          context 'when one pre-processing validator returns invalid' do
            before do
              # returns invalid
              allow(pre_processing_rule_validator_one_instance).to receive(:are_rules_valid).and_return(invalid_filtering_validation_result)
              # returns valid
              allow(pre_processing_rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
            end

            it_behaves_like 'filtering is invalid'

            it_behaves_like 'logs a warning'
          end

          context 'when pre-processing validators are present, one returns invalid but pre processing is inactive' do
            let(:rules_pre_processing_active) {
              false
            }

            it_behaves_like 'filtering is valid'
          end
        end

        context 'when post-processing validators are present' do
          let(:rules_validator_classes) {
            {
              Core::Filtering::ProcessingStage::POST => [
                post_processing_rule_validator_one_class,
                post_processing_rule_validator_two_class
              ]
            }
          }

          context 'when pre-processing validation is inactive' do
            let(:rules_pre_processing_active) {
              false
            }

            context 'when both post-processing validators return valid' do
              before do
                allow(post_processing_rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
                allow(post_processing_rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
              end

              it_behaves_like 'filtering is valid'
            end

            context 'when one post-processing validator returns invalid' do
              before do
                # returns invalid
                allow(post_processing_rule_validator_one_instance).to receive(:are_rules_valid).and_return(invalid_filtering_validation_result)
                # returns valid
                allow(post_processing_rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
              end

              it_behaves_like 'filtering is invalid'

              it_behaves_like 'logs a warning'
            end
          end

          context 'when pre-processing is active' do
            let(:rules_pre_processing_active) {
              true
            }

            context 'when one post-processing validator returns invalid' do
              before do
                # returns invalid
                allow(post_processing_rule_validator_one_instance).to receive(:are_rules_valid).and_return(invalid_filtering_validation_result)
                # returns valid
                allow(post_processing_rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
              end

              # should still be invalid as we always execute post processing
              it_behaves_like 'filtering is invalid'

              it_behaves_like 'logs a warning'
            end
          end
        end

        context 'when pre-, common- and post-processing validators are present' do
          let(:rules_validator_classes) {
            {
              Core::Filtering::ProcessingStage::PRE => [
                pre_processing_rule_validator_one_class,
                pre_processing_rule_validator_two_class
              ],
              Core::Filtering::ProcessingStage::ALL => [
                rule_validator_one_class,
                rule_validator_two_class
              ],
              Core::Filtering::ProcessingStage::POST => [
                post_processing_rule_validator_one_class,
                post_processing_rule_validator_two_class
              ]
            }
          }

          context 'when pre-processing is active' do
            let(:rules_pre_processing_active) {
              true
            }

            context 'when all return valid' do
              before do
                # pre-processing
                allow(pre_processing_rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
                allow(pre_processing_rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)

                # all stages
                allow(rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
                allow(rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)

                # post-processing
                allow(post_processing_rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
                allow(post_processing_rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
              end

              it_behaves_like 'filtering is valid'
            end

            context 'when one pre-processing validator returns invalid' do
              before do
                # pre-processing
                allow(pre_processing_rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
                # returns invalid
                allow(pre_processing_rule_validator_two_instance).to receive(:are_rules_valid).and_return(invalid_filtering_validation_result)

                # all stages
                allow(rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
                allow(rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)

                # post-processing
                allow(post_processing_rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
                allow(post_processing_rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
              end

              it_behaves_like 'filtering is invalid'
            end

            context 'when one common validator returns invalid' do
              before do
                # pre-processing
                allow(pre_processing_rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
                allow(pre_processing_rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)

                # all stages
                allow(rule_validator_one_instance).to receive(:are_rules_valid).and_return(invalid_filtering_validation_result)
                allow(rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)

                # post-processing
                allow(post_processing_rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
                allow(post_processing_rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
              end

              it_behaves_like 'filtering is invalid'
            end

            context 'when one post-processing validator returns invalid' do
              before do
                # pre-processing
                allow(pre_processing_rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
                allow(pre_processing_rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)

                # all stages
                allow(rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
                allow(rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)

                # post-processing
                allow(post_processing_rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
                # returns invalid
                allow(post_processing_rule_validator_two_instance).to receive(:are_rules_valid).and_return(invalid_filtering_validation_result)
              end

              it_behaves_like 'filtering is invalid'
            end
          end

          context 'when pre-processing is inactive' do
            let(:rules_pre_processing_active) {
              false
            }

            context 'when one pre-processing validator returns invalid' do
              before do
                # pre-processing
                allow(pre_processing_rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
                # returns invalid (is ignored)
                allow(pre_processing_rule_validator_two_instance).to receive(:are_rules_valid).and_return(invalid_filtering_validation_result)

                # all stages
                allow(rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
                allow(rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)

                # post-processing
                allow(post_processing_rule_validator_one_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
                allow(post_processing_rule_validator_two_instance).to receive(:are_rules_valid).and_return(valid_filtering_validation_result)
              end

              # pre-processing is not executed
              it_behaves_like 'filtering is valid'
            end
          end
        end
      end
    end
  end
end
