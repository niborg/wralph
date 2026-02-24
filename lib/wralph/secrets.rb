# frozen_string_literal: true

require 'yaml'
require 'ostruct'
require_relative 'interfaces/repo'
require_relative 'interfaces/print'

module Wralph
  class Secrets
    class << self
      def load
        @secrets ||= begin
          secrets_file = Interfaces::Repo.secrets_file
          return empty_secrets unless File.exist?(secrets_file)

          begin
            yaml_data = YAML.load_file(secrets_file)
            yaml_data = {} if yaml_data.nil? || yaml_data == false
            deep_struct(yaml_data)
          rescue Psych::SyntaxError => e
            Interfaces::Print.warning "Failed to parse #{secrets_file}: #{e.message}"
            empty_secrets
          end
        end

        @secrets
      end

      def reload
        reset
        load
      end

      def reset
        @secrets = nil
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

      def empty_secrets
        deep_struct({})
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
