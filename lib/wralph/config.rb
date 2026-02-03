# frozen_string_literal: true

require 'yaml'
require 'ostruct'
require_relative 'interfaces/repo'
require_relative 'interfaces/print'

module Wralph
  class Config
    class << self
      def load
        @config ||= begin
          config_file = Interfaces::Repo.config_file
          unless File.exist?(config_file)
            Interfaces::Print.warning "Config file #{config_file} not found, using default settings"
            return default_config
          end

          begin
            yaml_data = YAML.load_file(config_file)
            yaml_data = {} if yaml_data.nil? || yaml_data == false
            # Merge with defaults to ensure all keys exist
            merged_data = default_hash.merge(yaml_data) do |_key, default_val, yaml_val|
              if default_val.is_a?(Hash) && yaml_val.is_a?(Hash)
                default_val.merge(yaml_val)
              else
                yaml_val
              end
            end
            deep_struct(merged_data)
          rescue Psych::SyntaxError => e
            Interfaces::Print.warning "Failed to parse #{config_file}: #{e.message}"
            default_config
          end
        end

        @config
      end

      def reload
        @config = nil
        load
      end

      def reset
        @config = nil
      end

      def method_missing(method_name, *args, &block)
        if load.respond_to?(method_name)
          load.public_send(method_name, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        load.respond_to?(method_name, include_private) || super
      end

      private

      def default_hash
        {
          'objective_repository' => {
            'source' => 'github_issues'
          },
          'ci' => {
            'source' => 'circle_ci'
          },
          'agent_harness' => {
            'source' => 'claude_code'
          }
        }
      end

      def default_config
        deep_struct(default_hash)
      end

      def deep_struct(hash)
        return hash unless hash.is_a?(Hash)

        OpenStruct.new(
          hash.transform_values do |value|
            value.is_a?(Hash) ? deep_struct(value) : value
          end
        )
      end
    end
  end
end
