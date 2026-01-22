# frozen_string_literal: true

require 'yaml'
require_relative '../adapters/cis'
require_relative '../config'
require_relative 'repo'

module Wralph
  module Interfaces
    module Ci
      def self.build_status(pr_number, repo_owner, repo_name, api_token, verbose: true)
        adapter.build_status(pr_number, repo_owner, repo_name, api_token, verbose: verbose)
      end

      def self.wait_for_build(pr_number, repo_owner, repo_name, api_token)
        adapter.wait_for_build(pr_number, repo_owner, repo_name, api_token)
      end

      def self.build_failures(pr_number, repo_owner, repo_name, api_token)
        adapter.build_failures(pr_number, repo_owner, repo_name, api_token)
      end

      def self.api_token
        secrets = load_secrets
        token = secrets['ci_api_token']
        return nil unless token

        token = token.strip
        token.empty? ? nil : token
      end

      def self.reset_adapter
        @adapter = nil
      end

      def self.adapter
        @adapter ||= load_adapter
      end

      def self.load_adapter
        config = Config.load
        source = config.ci.source

        case source
        when 'circle_ci'
          Adapters::Cis::CircleCi
        when 'custom'
          load_custom_adapter(config.ci.class_name)
        else
          raise "Unknown CI source: #{source}"
        end
      end

      def self.load_custom_adapter(class_name)
        raise "class_name is required when source is 'custom'" if class_name.nil? || class_name.empty?

        # Convert class name to snake_case file path
        file_name = class_name_to_snake_case(class_name)
        adapter_file = File.join(Repo.wralph_dir, "#{file_name}.rb")

        raise "Custom adapter file not found: #{adapter_file}" unless File.exist?(adapter_file)

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
        required_methods = %i[build_status wait_for_build build_failures]
        missing_methods = required_methods.reject { |method| klass.respond_to?(method) }

        return if missing_methods.empty?

        raise "Custom adapter class must implement: #{missing_methods.join(', ')}"
      end

      def self.load_secrets
        secrets_file = Repo.secrets_file
        return {} unless File.exist?(secrets_file)

        begin
          YAML.load_file(secrets_file) || {}
        rescue Psych::SyntaxError => e
          Print.warning "Failed to parse #{secrets_file}: #{e.message}"
          {}
        end
      end
    end
  end
end
