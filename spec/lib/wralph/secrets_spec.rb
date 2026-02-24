# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require 'yaml'

RSpec.describe Wralph::Secrets do
  before do
    Wralph::Secrets.reset
  end

  describe '.load' do
    it 'returns empty secrets when secrets file does not exist' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          wralph_dir = File.join(tmpdir, '.wralph')
          FileUtils.rm_rf(wralph_dir) if Dir.exist?(wralph_dir)

          secrets = Wralph::Secrets.load
          expect(secrets.ci_api_token).to be_nil
        end
      end
    end

    it 'loads secrets from YAML file when it exists' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          wralph_dir = File.join(tmpdir, '.wralph')
          FileUtils.mkdir_p(wralph_dir)
          secrets_file = File.join(wralph_dir, 'secrets.yaml')

          secrets_data = {
            'ci_api_token' => 'my-secret-token'
          }
          File.write(secrets_file, secrets_data.to_yaml)

          secrets = Wralph::Secrets.load
          expect(secrets.ci_api_token).to eq('my-secret-token')
        end
      end
    end

    it 'caches the secrets on subsequent calls' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          wralph_dir = File.join(tmpdir, '.wralph')
          FileUtils.mkdir_p(wralph_dir)
          secrets_file = File.join(wralph_dir, 'secrets.yaml')

          File.write(secrets_file, "ci_api_token: first-token\n")

          secrets1 = Wralph::Secrets.load
          expect(secrets1.ci_api_token).to eq('first-token')

          File.write(secrets_file, "ci_api_token: second-token\n")

          secrets2 = Wralph::Secrets.load
          expect(secrets2.ci_api_token).to eq('first-token')
        end
      end
    end

    it 'returns empty secrets when YAML file has syntax errors' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          wralph_dir = File.join(tmpdir, '.wralph')
          FileUtils.mkdir_p(wralph_dir)
          secrets_file = File.join(wralph_dir, 'secrets.yaml')

          File.write(secrets_file, "invalid: yaml: content: [unclosed")

          secrets = Wralph::Secrets.load
          expect(secrets.ci_api_token).to be_nil
        end
      end
    end

    it 'handles empty YAML file' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          wralph_dir = File.join(tmpdir, '.wralph')
          FileUtils.mkdir_p(wralph_dir)
          secrets_file = File.join(wralph_dir, 'secrets.yaml')

          File.write(secrets_file, '')

          secrets = Wralph::Secrets.load
          expect(secrets.ci_api_token).to be_nil
        end
      end
    end
  end

  describe '.reload' do
    it 'reloads secrets from file' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          wralph_dir = File.join(tmpdir, '.wralph')
          FileUtils.mkdir_p(wralph_dir)
          secrets_file = File.join(wralph_dir, 'secrets.yaml')

          File.write(secrets_file, "ci_api_token: first-token\n")

          secrets1 = Wralph::Secrets.load
          expect(secrets1.ci_api_token).to eq('first-token')

          File.write(secrets_file, "ci_api_token: second-token\n")

          secrets2 = Wralph::Secrets.reload
          expect(secrets2.ci_api_token).to eq('second-token')
        end
      end
    end
  end

  describe 'method_missing for dot notation access' do
    it 'allows direct access to secret values via method calls' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          wralph_dir = File.join(tmpdir, '.wralph')
          FileUtils.mkdir_p(wralph_dir)
          secrets_file = File.join(wralph_dir, 'secrets.yaml')

          File.write(secrets_file, "ci_api_token: my-token\n")

          expect(Wralph::Secrets.ci_api_token).to eq('my-token')
        end
      end
    end
  end
end
