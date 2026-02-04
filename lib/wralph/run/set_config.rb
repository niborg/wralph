# frozen_string_literal: true

require 'fileutils'
require_relative '../interfaces/print'
require_relative '../interfaces/shell'
require_relative '../interfaces/repo'
require_relative 'init'

module Wralph
  module Run
    module SetConfig
      def self.run(issue_number)
        Init.ensure_initialized!

        # Check if we're currently in a worktree
        stdout, = Interfaces::Shell.run_command('git rev-parse --show-toplevel')
        stdout.strip
        Interfaces::Repo.repo_root

        # If we're in a worktree, the path will be different from the main repo root
        # We use git rev-parse to check if we're in a git-dir with a commondir (worktree indicator)
        _, _, is_worktree = Interfaces::Shell.run_command('test -f "$(git rev-parse --git-dir)/commondir"')

        if is_worktree
          Interfaces::Print.error 'Cannot run set_config from within a worktree.'
          Interfaces::Print.error 'Please run this command from the main repository.'
          exit 1
        end

        # Get the branch name for the issue
        branch_name = Interfaces::Repo.branch_name(issue_number)

        # Check if worktree exists for this issue
        worktrees = Interfaces::Shell.get_worktrees
        worktree = worktrees.find { |wt| wt['branch'] == branch_name }

        unless worktree
          Interfaces::Print.error "No worktree found for issue ##{issue_number} (branch: #{branch_name})"
          Interfaces::Print.error 'Please create a worktree first using the plan or execute command.'
          exit 1
        end

        # Get source and destination paths
        main_wralph_dir = Interfaces::Repo.wralph_dir
        worktree_wralph_dir = File.join(worktree['path'], '.wralph')

        unless Dir.exist?(main_wralph_dir)
          Interfaces::Print.error "Source .wralph directory not found at #{main_wralph_dir}"
          exit 1
        end

        # Copy .wralph contents to worktree
        Interfaces::Print.info "Copying .wralph contents to worktree at #{worktree['path']}..."

        # Create the destination directory if it doesn't exist
        FileUtils.mkdir_p(worktree_wralph_dir)

        # Copy all contents from main .wralph to worktree .wralph
        Dir.glob(File.join(main_wralph_dir, '*'), File::FNM_DOTMATCH).each do |item|
          next if ['.', '..'].include?(File.basename(item))

          dest_item = File.join(worktree_wralph_dir, File.basename(item))

          begin
            # Remove destination if it exists to ensure fresh copy
            FileUtils.rm_rf(dest_item) if File.exist?(dest_item)
            FileUtils.cp_r(item, dest_item)
            Interfaces::Print.info "  Copied #{File.basename(item)}"
          rescue StandardError => e
            Interfaces::Print.error "Failed to copy #{File.basename(item)}: #{e.message}"
            exit 1
          end
        end

        Interfaces::Print.success "Successfully copied .wralph contents to worktree for issue ##{issue_number}"
      end
    end
  end
end
