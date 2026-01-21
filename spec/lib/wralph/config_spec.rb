# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require 'yaml'

RSpec.describe Wralph::Config do
  before do
    Wralph::Config.reset
  end

  describe '.load' do
    it 'returns default config when config file does not exist' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          # Ensure .wralph directory doesn't exist
          wralph_dir = File.join(tmpdir, '.wralph')
          FileUtils.rm_rf(wralph_dir) if Dir.exist?(wralph_dir)

          config = Wralph::Config.load
          expect(config.objective_repository.source).to eq('github_issues')
        end
      end
    end

    it 'loads config from YAML file when it exists' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          wralph_dir = File.join(tmpdir, '.wralph')
          FileUtils.mkdir_p(wralph_dir)
          config_file = File.join(wralph_dir, 'config.yaml')

          config_data = {
            'objective_repository' => {
              'source' => 'custom_source'
            }
          }
          File.write(config_file, config_data.to_yaml)

          config = Wralph::Config.load
          expect(config.objective_repository.source).to eq('custom_source')
        end
      end
    end

    it 'caches the config on subsequent calls' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          wralph_dir = File.join(tmpdir, '.wralph')
          FileUtils.mkdir_p(wralph_dir)
          config_file = File.join(wralph_dir, 'config.yaml')

          config_data = {
            'objective_repository' => {
              'source' => 'first_value'
            }
          }
          File.write(config_file, config_data.to_yaml)

          config1 = Wralph::Config.load
          expect(config1.objective_repository.source).to eq('first_value')

          # Change the file
          config_data['objective_repository']['source'] = 'second_value'
          File.write(config_file, config_data.to_yaml)

          # Should still return cached value
          config2 = Wralph::Config.load
          expect(config2.objective_repository.source).to eq('first_value')
        end
      end
    end

    it 'returns default config when YAML file has syntax errors' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          wralph_dir = File.join(tmpdir, '.wralph')
          FileUtils.mkdir_p(wralph_dir)
          config_file = File.join(wralph_dir, 'config.yaml')

          # Write invalid YAML
          File.write(config_file, "invalid: yaml: content: [unclosed")

          config = Wralph::Config.load
          expect(config.objective_repository.source).to eq('github_issues')
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
          config_file = File.join(wralph_dir, 'config.yaml')

          File.write(config_file, '')

          config = Wralph::Config.load
          expect(config.objective_repository.source).to eq('github_issues')
        end
      end
    end
  end

  describe '.reload' do
    it 'reloads config from file' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          wralph_dir = File.join(tmpdir, '.wralph')
          FileUtils.mkdir_p(wralph_dir)
          config_file = File.join(wralph_dir, 'config.yaml')

          config_data = {
            'objective_repository' => {
              'source' => 'first_value'
            }
          }
          File.write(config_file, config_data.to_yaml)

          config1 = Wralph::Config.load
          expect(config1.objective_repository.source).to eq('first_value')

          # Change the file
          config_data['objective_repository']['source'] = 'second_value'
          File.write(config_file, config_data.to_yaml)

          # Reload should pick up the new value
          config2 = Wralph::Config.reload
          expect(config2.objective_repository.source).to eq('second_value')
        end
      end
    end
  end

  describe 'method_missing for dot notation access' do
    it 'allows direct access to config values via method calls' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          wralph_dir = File.join(tmpdir, '.wralph')
          FileUtils.mkdir_p(wralph_dir)
          config_file = File.join(wralph_dir, 'config.yaml')

          config_data = {
            'objective_repository' => {
              'source' => 'github_issues'
            }
          }
          File.write(config_file, config_data.to_yaml)

          # Should be able to call methods directly on Config
          expect(Wralph::Config.objective_repository.source).to eq('github_issues')
        end
      end
    end
  end
end
