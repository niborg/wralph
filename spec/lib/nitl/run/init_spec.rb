# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe Nitl::Run::Init do
  describe '.run' do
    it 'creates .nitl directory and plans subdirectory' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          Nitl::Run::Init.run

          nitl_dir = File.join(tmpdir, '.nitl')
          plans_dir = File.join(nitl_dir, 'plans')
          secrets_file = File.join(nitl_dir, 'secrets.yaml')

          expect(Dir.exist?(nitl_dir)).to be true
          expect(Dir.exist?(plans_dir)).to be true
          expect(File.exist?(secrets_file)).to be true
          expect(File.read(secrets_file)).to include('ci_api_token')
        end
      end
    end

    it 'does not fail if .nitl already exists' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          # Initialize once
          Nitl::Run::Init.run
          # Initialize again - should not fail
          expect { Nitl::Run::Init.run }.not_to raise_error
        end
      end
    end

    it 'does not overwrite secrets.yaml if it already exists' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          nitl_dir = File.join(tmpdir, '.nitl')
          secrets_file = File.join(nitl_dir, 'secrets.yaml')

          # Create .nitl directory and custom secrets.yaml
          FileUtils.mkdir_p(nitl_dir)
          custom_secrets = "ci_api_token: my-custom-token\ncustom_setting: value"
          File.write(secrets_file, custom_secrets)

          # Run init
          Nitl::Run::Init.run

          # Verify secrets.yaml was not overwritten
          expect(File.read(secrets_file)).to eq(custom_secrets)
        end
      end
    end

    it 'adds .nitl/secrets.yaml to .gitignore when .gitignore does not exist' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          gitignore_path = File.join(tmpdir, '.gitignore')
          expect(File.exist?(gitignore_path)).to be false

          Nitl::Run::Init.run

          expect(File.exist?(gitignore_path)).to be true
          gitignore_content = File.read(gitignore_path)
          expect(gitignore_content).to include('.nitl/secrets.yaml')
        end
      end
    end

    it 'adds .nitl/secrets.yaml to .gitignore when .gitignore exists but does not contain the entry' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          gitignore_path = File.join(tmpdir, '.gitignore')
          File.write(gitignore_path, "# Existing ignore\n*.log\n")

          Nitl::Run::Init.run

          gitignore_content = File.read(gitignore_path)
          expect(gitignore_content).to include('.nitl/secrets.yaml')
          expect(gitignore_content).to include('# Existing ignore')
          expect(gitignore_content).to include('*.log')
        end
      end
    end

    it 'does not duplicate .nitl/secrets.yaml in .gitignore if it already exists' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          gitignore_path = File.join(tmpdir, '.gitignore')
          File.write(gitignore_path, ".nitl/secrets.yaml\n*.log\n")

          Nitl::Run::Init.run

          gitignore_content = File.read(gitignore_path)
          expect(gitignore_content.scan('.nitl/secrets.yaml').count).to eq(1)
        end
      end
    end
  end

  describe '.initialized?' do
    it 'returns false when .nitl does not exist' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          expect(Nitl::Run::Init.initialized?).to be false
        end
      end
    end

    it 'returns true when .nitl exists' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          Nitl::Run::Init.run
          expect(Nitl::Run::Init.initialized?).to be true
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
          expect { Nitl::Run::Init.ensure_initialized! }.to raise_error(SystemExit) do |error|
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
          Nitl::Run::Init.run
          expect { Nitl::Run::Init.ensure_initialized! }.not_to raise_error
        end
      end
    end
  end
end
