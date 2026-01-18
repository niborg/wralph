# frozen_string_literal: true

require 'yaml'
require_relative '../adapters/ci'
require_relative 'repo'

module Nitl
  module Interfaces
    module Ci
      def self.build_status(pr_number, repo_owner, repo_name, api_token, verbose: true)
        Adapters::Ci::CircleCi.build_status(pr_number, repo_owner, repo_name, api_token, verbose: verbose)
      end

      def self.wait_for_build(pr_number, repo_owner, repo_name, api_token)
        Adapters::Ci::CircleCi.wait_for_build(pr_number, repo_owner, repo_name, api_token)
      end

      def self.build_failures(pr_number, repo_owner, repo_name, api_token)
        Adapters::Ci::CircleCi.build_failures(pr_number, repo_owner, repo_name, api_token)
      end

      def self.api_token
        secrets = load_secrets
        token = secrets['ci_api_token']
        return nil unless token

        token = token.strip
        token.empty? ? nil : token
      end

      private

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
