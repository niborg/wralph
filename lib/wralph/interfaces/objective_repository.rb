# frozen_string_literal: true

require_relative '../adapters/objective_repositories'

module Wralph
  module Interfaces
    module ObjectiveRepository
      def self.download!(identifier)
        Adapters::ObjectiveRepositories::GithubIssues.download!(identifier)
      end

      def self.local_file_path(identifier)
        Adapters::ObjectiveRepositories::GithubIssues.local_file_path(identifier)
      end
    end
  end
end
