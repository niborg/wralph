# frozen_string_literal: true

require_relative '../adapters/objective_repositories'
require_relative '../config'

module Wralph
  module Interfaces
    module ObjectiveRepository
      def self.download!(identifier)
        adapter.download!(identifier)
      end

      def self.local_file_path(identifier)
        adapter.local_file_path(identifier)
      end

      def self.reset_adapter
        @adapter = nil
      end

      private

      def self.adapter
        @adapter ||= load_adapter
      end

      def self.load_adapter
        config = Config.load
        source = config.objective_repository.source

        case source
        when 'github_issues'
          Adapters::ObjectiveRepositories::GithubIssues
        when 'custom'
          load_custom_adapter(config.objective_repository.class_name)
        else
          raise "Unknown objective_repository source: #{source}"
        end
      end

      def self.load_custom_adapter(class_name)
        raise "class_name is required when source is 'custom'" if class_name.nil? || class_name.empty?

        # Convert class name to snake_case file path
        file_name = class_name_to_snake_case(class_name)
        adapter_file = File.join(Repo.wralph_dir, "#{file_name}.rb")

        unless File.exist?(adapter_file)
          raise "Custom adapter file not found: #{adapter_file}"
        end

        # Load the file
        load adapter_file

        # Get the class constant
        begin
          klass = Object.const_get(class_name)
          validate_adapter_interface(klass)
          klass
        rescue NameError => e
          raise "Failed to load custom adapter class '#{class_name}': #{e.message}"
        end
      end

      def self.class_name_to_snake_case(class_name)
        # Convert CamelCase to snake_case
        # Insert underscore before capital letters (except the first one)
        # Then downcase everything
        class_name
          .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .downcase
      end

      def self.validate_adapter_interface(klass)
        required_methods = [:download!, :local_file_path]
        missing_methods = required_methods.reject { |method| klass.respond_to?(method) }

        unless missing_methods.empty?
          raise "Custom adapter class must implement: #{missing_methods.join(', ')}"
        end
      end
    end
  end
end
