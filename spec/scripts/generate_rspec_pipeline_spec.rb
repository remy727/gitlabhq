# frozen_string_literal: true

require 'fast_spec_helper'
require 'tempfile'

require_relative '../../scripts/generate_rspec_pipeline'

RSpec.describe GenerateRspecPipeline, :silence_stdout, feature_category: :tooling do
  describe '#generate!' do
    let!(:rspec_files) { Tempfile.new(['rspec_files_path', '.txt']) }
    let(:rspec_files_content) do
      "spec/migrations/a_spec.rb spec/migrations/b_spec.rb " \
        "spec/lib/gitlab/background_migration/a_spec.rb spec/lib/gitlab/background_migration/b_spec.rb " \
        "spec/models/a_spec.rb spec/models/b_spec.rb " \
        "spec/controllers/a_spec.rb spec/controllers/b_spec.rb " \
        "spec/features/a_spec.rb spec/features/b_spec.rb"
    end

    let(:pipeline_template) { Tempfile.new(['pipeline_template', '.yml.erb']) }
    let(:pipeline_template_content) do
      <<~YAML
      <% if rspec_files_per_test_level[:migration][:files].size > 0 %>
      rspec migration:
      <% if rspec_files_per_test_level[:migration][:parallelization] > 1 %>
        parallel: <%= rspec_files_per_test_level[:migration][:parallelization] %>
      <% end %>
      <% end %>
      <% if rspec_files_per_test_level[:background_migration][:files].size > 0 %>
      rspec background_migration:
      <% if rspec_files_per_test_level[:background_migration][:parallelization] > 1 %>
        parallel: <%= rspec_files_per_test_level[:background_migration][:parallelization] %>
      <% end %>
      <% end %>
      <% if rspec_files_per_test_level[:unit][:files].size > 0 %>
      rspec unit:
      <% if rspec_files_per_test_level[:unit][:parallelization] > 1 %>
        parallel: <%= rspec_files_per_test_level[:unit][:parallelization] %>
      <% end %>
      <% end %>
      <% if rspec_files_per_test_level[:integration][:files].size > 0 %>
      rspec integration:
      <% if rspec_files_per_test_level[:integration][:parallelization] > 1 %>
        parallel: <%= rspec_files_per_test_level[:integration][:parallelization] %>
      <% end %>
      <% end %>
      <% if rspec_files_per_test_level[:system][:files].size > 0 %>
      rspec system:
      <% if rspec_files_per_test_level[:system][:parallelization] > 1 %>
        parallel: <%= rspec_files_per_test_level[:system][:parallelization] %>
      <% end %>
      <% end %>
      YAML
    end

    let(:knapsack_report) { Tempfile.new(['knapsack_report', '.json']) }
    let(:knapsack_report_content) do
      <<~JSON
      {
        "spec/migrations/a_spec.rb": 360.3,
        "spec/migrations/b_spec.rb": 180.1,
        "spec/lib/gitlab/background_migration/a_spec.rb": 60.5,
        "spec/lib/gitlab/background_migration/b_spec.rb": 180.3,
        "spec/models/a_spec.rb": 360.2,
        "spec/models/b_spec.rb": 180.6,
        "spec/controllers/a_spec.rb": 60.2,
        "spec/controllers/ab_spec.rb": 180.4,
        "spec/features/a_spec.rb": 360.1,
        "spec/features/b_spec.rb": 180.5
      }
      JSON
    end

    around do |example|
      rspec_files.write(rspec_files_content)
      rspec_files.rewind
      pipeline_template.write(pipeline_template_content)
      pipeline_template.rewind
      knapsack_report.write(knapsack_report_content)
      knapsack_report.rewind
      example.run
    ensure
      rspec_files.close
      rspec_files.unlink
      pipeline_template.close
      pipeline_template.unlink
      knapsack_report.close
      knapsack_report.unlink
    end

    context 'when rspec_files and pipeline_template_path exists' do
      subject do
        described_class.new(
          rspec_files_path: rspec_files.path,
          pipeline_template_path: pipeline_template.path
        )
      end

      it 'generates the pipeline config with default parallelization' do
        subject.generate!

        expect(File.read("#{pipeline_template.path}.yml"))
          .to eq(
            "rspec migration:\nrspec background_migration:\nrspec unit:\n" \
            "rspec integration:\nrspec system:"
          )
      end

      context 'when parallelization > 0' do
        before do
          stub_const("#{described_class}::DEFAULT_AVERAGE_TEST_FILE_DURATION_IN_SECONDS", 360)
        end

        it 'generates the pipeline config' do
          subject.generate!

          expect(File.read("#{pipeline_template.path}.yml"))
            .to eq(
              "rspec migration:\n  parallel: 2\nrspec background_migration:\n  parallel: 2\n" \
              "rspec unit:\n  parallel: 2\nrspec integration:\n  parallel: 2\n" \
              "rspec system:\n  parallel: 2"
            )
        end
      end

      context 'when parallelization > MAX_NODES_COUNT' do
        let(:rspec_files_content) do
          Array.new(51) { |i| "spec/migrations/#{i}_spec.rb" }.join(' ')
        end

        before do
          stub_const(
            "#{described_class}::DEFAULT_AVERAGE_TEST_FILE_DURATION_IN_SECONDS",
            described_class::OPTIMAL_TEST_JOB_DURATION_IN_SECONDS
          )
        end

        it 'generates the pipeline config with max parallelization of 50' do
          subject.generate!

          expect(File.read("#{pipeline_template.path}.yml")).to eq("rspec migration:\n  parallel: 50")
        end
      end
    end

    context 'when knapsack_report_path is given' do
      subject do
        described_class.new(
          rspec_files_path: rspec_files.path,
          pipeline_template_path: pipeline_template.path,
          knapsack_report_path: knapsack_report.path
        )
      end

      it 'generates the pipeline config with parallelization based on Knapsack' do
        subject.generate!

        expect(File.read("#{pipeline_template.path}.yml"))
          .to eq(
            "rspec migration:\n  parallel: 2\nrspec background_migration:\n" \
            "rspec unit:\n  parallel: 2\nrspec integration:\n" \
            "rspec system:\n  parallel: 2"
          )
      end

      context 'and Knapsack report does not contain valid JSON' do
        let(:knapsack_report_content) { "#{super()}," }

        it 'generates the pipeline config with default parallelization' do
          subject.generate!

          expect(File.read("#{pipeline_template.path}.yml"))
            .to eq(
              "rspec migration:\nrspec background_migration:\nrspec unit:\n" \
              "rspec integration:\nrspec system:"
            )
        end
      end
    end

    context 'when rspec_files does not exist' do
      subject { described_class.new(rspec_files_path: nil, pipeline_template_path: pipeline_template.path) }

      it 'generates the pipeline config using the no-op template' do
        subject.generate!

        expect(File.read("#{pipeline_template.path}.yml")).to include("no-op:")
      end
    end

    context 'when pipeline_template_path does not exist' do
      subject { described_class.new(rspec_files_path: rspec_files.path, pipeline_template_path: nil) }

      it 'generates the pipeline config using the no-op template' do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end
end
