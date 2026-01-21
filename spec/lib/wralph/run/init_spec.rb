# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe Wralph::Run::Init do
  describe '.run' do
    it 'creates .wralph directory and plans subdirectory' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          Wralph::Run::Init.run

          wralph_dir = File.join(tmpdir, '.wralph')
          plans_dir = File.join(wralph_dir, 'plans')
          secrets_file = File.join(wralph_dir, 'secrets.yaml')
          config_file = File.join(wralph_dir, 'config.yaml')

          expect(Dir.exist?(wralph_dir)).to be true
          expect(Dir.exist?(plans_dir)).to be true
          expect(File.exist?(secrets_file)).to be true
          expect(File.read(secrets_file)).to include('ci_api_token')
          expect(File.exist?(config_file)).to be true
          expect(File.read(config_file)).to include('objective_repository')
          expect(File.read(config_file)).to include('source: github_issues')
        end
      end
    end

    it 'does not fail if .wralph already exists' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          # Initialize once
          Wralph::Run::Init.run
          # Initialize again - should not fail
          expect { Wralph::Run::Init.run }.not_to raise_error
        end
      end
    end

    it 'does not overwrite secrets.yaml if it already exists' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          wralph_dir = File.join(tmpdir, '.wralph')
          secrets_file = File.join(wralph_dir, 'secrets.yaml')

          # Create .wralph directory and custom secrets.yaml
          FileUtils.mkdir_p(wralph_dir)
          custom_secrets = "ci_api_token: my-custom-token\ncustom_setting: value"
          File.write(secrets_file, custom_secrets)

          # Run init
          Wralph::Run::Init.run

          # Verify secrets.yaml was not overwritten
          expect(File.read(secrets_file)).to eq(custom_secrets)
        end
      end
    end

    it 'does not overwrite config.yaml if it already exists' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          wralph_dir = File.join(tmpdir, '.wralph')
          config_file = File.join(wralph_dir, 'config.yaml')

          # Create .wralph directory and custom config.yaml
          FileUtils.mkdir_p(wralph_dir)
          custom_config = "objective_repository:\n  source: custom_source\n"
          File.write(config_file, custom_config)

          # Run init
          Wralph::Run::Init.run

          # Verify config.yaml was not overwritten
          expect(File.read(config_file)).to eq(custom_config)
        end
      end
    end

    it 'adds .wralph/secrets.yaml to .gitignore when .gitignore does not exist' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          gitignore_path = File.join(tmpdir, '.gitignore')
          expect(File.exist?(gitignore_path)).to be false

          Wralph::Run::Init.run

          expect(File.exist?(gitignore_path)).to be true
          gitignore_content = File.read(gitignore_path)
          expect(gitignore_content).to include('.wralph/secrets.yaml')
        end
      end
    end

    it 'adds .wralph/secrets.yaml to .gitignore when .gitignore exists but does not contain the entry' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          gitignore_path = File.join(tmpdir, '.gitignore')
          File.write(gitignore_path, "# Existing ignore\n*.log\n")

          Wralph::Run::Init.run

          gitignore_content = File.read(gitignore_path)
          expect(gitignore_content).to include('.wralph/secrets.yaml')
          expect(gitignore_content).to include('# Existing ignore')
          expect(gitignore_content).to include('*.log')
        end
      end
    end

    it 'does not duplicate .wralph/secrets.yaml in .gitignore if it already exists' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          gitignore_path = File.join(tmpdir, '.gitignore')
          File.write(gitignore_path, ".wralph/secrets.yaml\n*.log\n")

          Wralph::Run::Init.run

          gitignore_content = File.read(gitignore_path)
          expect(gitignore_content.scan('.wralph/secrets.yaml').count).to eq(1)
        end
      end
    end
  end

  describe '.initialized?' do
    it 'returns false when .wralph does not exist' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          expect(Wralph::Run::Init.initialized?).to be false
        end
      end
    end

    it 'returns true when .wralph exists' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          Wralph::Run::Init.run
          expect(Wralph::Run::Init.initialized?).to be true
        end
      end
    end
  end

  describe '.ensure_initialized!' do
    it 'exits with error when not initialized' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          expect { Wralph::Run::Init.ensure_initialized! }.to raise_error(SystemExit) do |error|
            expect(error.status).to eq(1)
          end
        end
      end
    end

    it 'does not exit when initialized' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          Wralph::Run::Init.run
          expect { Wralph::Run::Init.ensure_initialized! }.not_to raise_error
        end
      end
    end
  end
end
