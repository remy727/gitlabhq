# frozen_string_literal: true

module Gitlab
  module Config
    module Loader
      class MultiDocYaml
        include Gitlab::Utils::StrongMemoize

        MULTI_DOC_DIVIDER = /^---\s+/.freeze

        def initialize(config, max_documents:, additional_permitted_classes: [])
          @config = config
          @max_documents = max_documents
          @additional_permitted_classes = additional_permitted_classes
        end

        def valid?
          documents.all?(&:valid?)
        end

        def load_raw!
          documents.map(&:load_raw!)
        end

        def load!
          documents.map(&:load!)
        end

        private

        attr_reader :config, :max_documents, :additional_permitted_classes

        # Valid YAML files can start with either a leading delimiter or no delimiter.
        # To avoid counting a leading delimiter towards the document limit,
        # this method splits the file by one more than the maximum number of permitted documents.
        # It then discards the first document if it is blank.
        def documents
          docs = config
                  .split(MULTI_DOC_DIVIDER, max_documents_including_leading_delimiter)
                  .map { |d| Yaml.new(d, additional_permitted_classes: additional_permitted_classes) }

          docs.shift if docs.first.blank?
          docs
        end
        strong_memoize_attr :documents

        def max_documents_including_leading_delimiter
          max_documents + 1
        end
      end
    end
  end
end
