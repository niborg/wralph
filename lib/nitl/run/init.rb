# frozen_string_literal: true

require 'fileutils'
require_relative '../interfaces/repo'
require_relative '../interfaces/print'

module Nitl
  module Run
    module Init
      def self.run
        nitl_dir = Interfaces::Repo.nitl_dir
        plans_dir = Interfaces::Repo.plans_dir

        if Dir.exist?(nitl_dir)
          Interfaces::Print.warning ".nitl directory already exists at #{nitl_dir}"
          Interfaces::Print.info "Skipping initialization"
          return
        end

        # Create .nitl directory
        FileUtils.mkdir_p(nitl_dir)
        Interfaces::Print.success "Created .nitl directory at #{nitl_dir}"

        # Create plans subdirectory
        FileUtils.mkdir_p(plans_dir)
        Interfaces::Print.success "Created .nitl/plans directory"

        # Create secrets.yaml template
        secrets_file = Interfaces::Repo.secrets_file
        unless File.exist?(secrets_file)
          secrets_template = <<~YAML
            # NITL Secrets Configuration
            # Add your CI API tokens and other secrets here
            # This file is git-ignored for security

            ci_api_token: # Add your CircleCI API token here
          YAML

          File.write(secrets_file, secrets_template)
          Interfaces::Print.success "Created .nitl/secrets.yaml template"
        end

        Interfaces::Print.success "NITL initialized successfully!"
        Interfaces::Print.info "You can now use 'nitl plan <issue_number>' to get started"
      end

      def self.initialized?
        nitl_dir = Interfaces::Repo.nitl_dir
        Dir.exist?(nitl_dir)
      end

      def self.ensure_initialized!
        return if initialized?

        Interfaces::Print.error "NITL has not been initialized in this repository."
        Interfaces::Print.error ""
        Interfaces::Print.error "Please run 'nitl init' first to set up NITL."
        exit 1
      rescue SystemExit
        raise
      rescue => e
        Interfaces::Print.error "Error checking initialization: #{e.message}"
        exit 1
      end
    end
  end
end
