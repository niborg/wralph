# frozen_string_literal: true

require 'fileutils'
require 'shellwords'
require_relative '../../interfaces/shell'
require_relative '../../interfaces/repo'

module Wralph
  module Adapters
    module ObjectiveRepositories
      module GithubIssues
        def self.download!(identifier)
          # Ensure objectives directory exists
          objectives_dir = File.join(Interfaces::Repo.wralph_dir, 'objectives')
          FileUtils.mkdir_p(objectives_dir)

          # Get the local file path
          file_path = local_file_path(identifier)

          # Fetch GitHub issue content
          issue_content, stderr, success = Interfaces::Shell.run_command("gh issue view #{Shellwords.shellescape(identifier)}")
          raise "Failed to download GitHub issue ##{identifier}: #{stderr}" unless success

          # Write the issue content to the file (overwrites if exists)
          File.write(file_path, issue_content)

          file_path
        end

        def self.local_file_path(identifier)
          objectives_dir = File.join(Interfaces::Repo.wralph_dir, 'objectives')
          File.join(objectives_dir, "#{identifier}.md")
        end
      end
    end
  end
end
