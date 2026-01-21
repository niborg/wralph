# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe Wralph::Interfaces::ObjectiveRepository do
  before do
    Wralph::Config.reset
    described_class.reset_adapter
  end

  describe '.download!' do
    context 'with github_issues source' do
      it 'uses GithubIssues adapter' do
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

            # Mock the adapter to avoid actual GitHub API calls
            allow(Wralph::Adapters::ObjectiveRepositories::GithubIssues).to receive(:download!).and_return('/path/to/file.md')

            result = described_class.download!('123')
            expect(result).to eq('/path/to/file.md')
            expect(Wralph::Adapters::ObjectiveRepositories::GithubIssues).to have_received(:download!).with('123')
          end
        end
      end
    end

    context 'with custom source' do
      it 'loads and uses custom adapter class' do
        Dir.mktmpdir do |tmpdir|
          git_dir = File.join(tmpdir, '.git')
          Dir.mkdir(git_dir)

          Dir.chdir(tmpdir) do
            wralph_dir = File.join(tmpdir, '.wralph')
            FileUtils.mkdir_p(wralph_dir)
            config_file = File.join(wralph_dir, 'config.yaml')

            config_data = {
              'objective_repository' => {
                'source' => 'custom',
                'class_name' => 'MyCustomAdapter'
              }
            }
            File.write(config_file, config_data.to_yaml)

            # Create custom adapter file
            custom_adapter_file = File.join(wralph_dir, 'my_custom_adapter.rb')
            custom_adapter_code = <<~RUBY
              class MyCustomAdapter
                def self.download!(identifier)
                  "/custom/path/\#{identifier}.md"
                end

                def self.local_file_path(identifier)
                  "/custom/path/\#{identifier}.md"
                end
              end
            RUBY
            File.write(custom_adapter_file, custom_adapter_code)

            result = described_class.download!('123')
            expect(result).to eq('/custom/path/123.md')
          end
        end
      end

      it 'raises error if class_name is missing' do
        Dir.mktmpdir do |tmpdir|
          git_dir = File.join(tmpdir, '.git')
          Dir.mkdir(git_dir)

          Dir.chdir(tmpdir) do
            wralph_dir = File.join(tmpdir, '.wralph')
            FileUtils.mkdir_p(wralph_dir)
            config_file = File.join(wralph_dir, 'config.yaml')

            config_data = {
              'objective_repository' => {
                'source' => 'custom'
              }
            }
            File.write(config_file, config_data.to_yaml)

            expect { described_class.download!('123') }.to raise_error(/class_name is required/)
          end
        end
      end

      it 'raises error if adapter file does not exist' do
        Dir.mktmpdir do |tmpdir|
          git_dir = File.join(tmpdir, '.git')
          Dir.mkdir(git_dir)

          Dir.chdir(tmpdir) do
            wralph_dir = File.join(tmpdir, '.wralph')
            FileUtils.mkdir_p(wralph_dir)
            config_file = File.join(wralph_dir, 'config.yaml')

            config_data = {
              'objective_repository' => {
                'source' => 'custom',
                'class_name' => 'NonExistentAdapter'
              }
            }
            File.write(config_file, config_data.to_yaml)

            expect { described_class.download!('123') }.to raise_error(/Custom adapter file not found/)
          end
        end
      end

      it 'raises error if adapter class does not implement required methods' do
        Dir.mktmpdir do |tmpdir|
          git_dir = File.join(tmpdir, '.git')
          Dir.mkdir(git_dir)

          Dir.chdir(tmpdir) do
            wralph_dir = File.join(tmpdir, '.wralph')
            FileUtils.mkdir_p(wralph_dir)
            config_file = File.join(wralph_dir, 'config.yaml')

            config_data = {
              'objective_repository' => {
                'source' => 'custom',
                'class_name' => 'IncompleteAdapter'
              }
            }
            File.write(config_file, config_data.to_yaml)

            # Create adapter file without required methods
            adapter_file = File.join(wralph_dir, 'incomplete_adapter.rb')
            File.write(adapter_file, 'class IncompleteAdapter; end')

            expect { described_class.download!('123') }.to raise_error(/must implement/)
          end
        end
      end

      it 'handles complex class names correctly' do
        Dir.mktmpdir do |tmpdir|
          git_dir = File.join(tmpdir, '.git')
          Dir.mkdir(git_dir)

          Dir.chdir(tmpdir) do
            wralph_dir = File.join(tmpdir, '.wralph')
            FileUtils.mkdir_p(wralph_dir)
            config_file = File.join(wralph_dir, 'config.yaml')

            config_data = {
              'objective_repository' => {
                'source' => 'custom',
                'class_name' => 'MyCustomObjectiveAdapter'
              }
            }
            File.write(config_file, config_data.to_yaml)

            # Create adapter file with complex name
            adapter_file = File.join(wralph_dir, 'my_custom_objective_adapter.rb')
            adapter_code = <<~RUBY
              class MyCustomObjectiveAdapter
                def self.download!(identifier)
                  "/complex/path/\#{identifier}.md"
                end

                def self.local_file_path(identifier)
                  "/complex/path/\#{identifier}.md"
                end
              end
            RUBY
            File.write(adapter_file, adapter_code)

            result = described_class.download!('456')
            expect(result).to eq('/complex/path/456.md')
          end
        end
      end
    end

    context 'with unknown source' do
      it 'raises error' do
        Dir.mktmpdir do |tmpdir|
          git_dir = File.join(tmpdir, '.git')
          Dir.mkdir(git_dir)

          Dir.chdir(tmpdir) do
            wralph_dir = File.join(tmpdir, '.wralph')
            FileUtils.mkdir_p(wralph_dir)
            config_file = File.join(wralph_dir, 'config.yaml')

            config_data = {
              'objective_repository' => {
                'source' => 'unknown_source'
              }
            }
            File.write(config_file, config_data.to_yaml)

            expect { described_class.download!('123') }.to raise_error(/Unknown objective_repository source/)
          end
        end
      end
    end
  end

  describe '.local_file_path' do
    it 'delegates to the configured adapter' do
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

          allow(Wralph::Adapters::ObjectiveRepositories::GithubIssues).to receive(:local_file_path).and_return('/path/to/123.md')

          result = described_class.local_file_path('123')
          expect(result).to eq('/path/to/123.md')
          expect(Wralph::Adapters::ObjectiveRepositories::GithubIssues).to have_received(:local_file_path).with('123')
        end
      end
    end
  end
end
