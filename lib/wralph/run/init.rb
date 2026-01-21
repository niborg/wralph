# frozen_string_literal: true

require 'fileutils'
require_relative '../interfaces/repo'
require_relative '../interfaces/print'

module Wralph
  module Run
    module Init
      def self.run
        wralph_dir = Interfaces::Repo.wralph_dir
        plans_dir = Interfaces::Repo.plans_dir

        if Dir.exist?(wralph_dir)
          Interfaces::Print.warning ".wralph directory already exists at #{wralph_dir}"
          Interfaces::Print.info "Skipping initialization"
          return
        end

        # Create .wralph directory
        FileUtils.mkdir_p(wralph_dir)
        Interfaces::Print.success "Created .wralph directory at #{wralph_dir}"

        # Create plans subdirectory
        FileUtils.mkdir_p(plans_dir)
        Interfaces::Print.success "Created .wralph/plans directory"

        # Create secrets.yaml template
        secrets_file = Interfaces::Repo.secrets_file
        unless File.exist?(secrets_file)
          secrets_fixture = Interfaces::Repo.fixture_file('secrets.yaml')
          if File.exist?(secrets_fixture)
            FileUtils.cp(secrets_fixture, secrets_file)
            Interfaces::Print.success "Created .wralph/secrets.yaml template"
          else
            Interfaces::Print.warning "Fixture file not found: #{secrets_fixture}"
          end
        end

        # Create config.yaml template
        config_file = Interfaces::Repo.config_file
        unless File.exist?(config_file)
          config_fixture = Interfaces::Repo.fixture_file('config.yaml')
          if File.exist?(config_fixture)
            FileUtils.cp(config_fixture, config_file)
            Interfaces::Print.success "Created .wralph/config.yaml template"
          else
            Interfaces::Print.warning "Fixture file not found: #{config_fixture}"
          end
        end

        # Ensure .wralph/secrets.yaml is in .gitignore
        update_gitignore

        Interfaces::Print.success "WRALPH initialized successfully!"
        Interfaces::Print.info "You can now use 'wralph plan <issue_number>' to get started"
      end

      def self.initialized?
        wralph_dir = Interfaces::Repo.wralph_dir
        Dir.exist?(wralph_dir)
      end

      def self.ensure_initialized!
        return if initialized?

        Interfaces::Print.error "WRALPH has not been initialized in this repository."
        Interfaces::Print.error ""
        Interfaces::Print.error "Please run 'wralph init' first to set up WRALPH."
        exit 1
      rescue SystemExit
        raise
      rescue => e
        Interfaces::Print.error "Error checking initialization: #{e.message}"
        exit 1
      end

      def self.update_gitignore
        repo_root = Interfaces::Repo.repo_root
        gitignore_path = File.join(repo_root, '.gitignore')
        secrets_ignore_entry = '.wralph/secrets.yaml'

        # Check if entry already exists
        if File.exist?(gitignore_path)
          content = File.read(gitignore_path)
          return if content.include?(secrets_ignore_entry)
        end

        # Add entry to .gitignore
        entry = "\n# WRALPH secrets\n#{secrets_ignore_entry}\n"
        File.open(gitignore_path, 'a') do |f|
          f.write(entry)
        end
        Interfaces::Print.success "Added .wralph/secrets.yaml to .gitignore"
      end
    end
  end
end
