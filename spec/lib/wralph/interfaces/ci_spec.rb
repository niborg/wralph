# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe Wralph::Interfaces::Ci do
  before do
    Wralph::Config.reset
    described_class.reset_adapter
  end

  describe '.build_status' do
    context 'with circle_ci source' do
      it 'uses CircleCi adapter' do
        Dir.mktmpdir do |tmpdir|
          git_dir = File.join(tmpdir, '.git')
          Dir.mkdir(git_dir)

          Dir.chdir(tmpdir) do
            wralph_dir = File.join(tmpdir, '.wralph')
            FileUtils.mkdir_p(wralph_dir)
            config_file = File.join(wralph_dir, 'config.yaml')

            config_data = {
              'ci' => {
                'source' => 'circle_ci'
              }
            }
            File.write(config_file, config_data.to_yaml)

            # Mock the adapter to avoid actual API calls
            allow(Wralph::Adapters::Cis::CircleCi).to receive(:build_status).and_return('success')

            result = described_class.build_status('123', 'owner', 'repo', 'token')
            expect(result).to eq('success')
            expect(Wralph::Adapters::Cis::CircleCi).to have_received(:build_status).with('123', 'owner', 'repo', 'token', verbose: true)
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
              'ci' => {
                'source' => 'custom',
                'class_name' => 'MyCustomCiAdapter'
              }
            }
            File.write(config_file, config_data.to_yaml)

            # Create custom adapter file
            custom_adapter_file = File.join(wralph_dir, 'my_custom_ci_adapter.rb')
            custom_adapter_code = <<~RUBY
              class MyCustomCiAdapter
                def self.build_status(pr_number, repo_owner, repo_name, api_token, verbose: true)
                  'custom_success'
                end

                def self.wait_for_build(pr_number, repo_owner, repo_name, api_token)
                  true
                end

                def self.build_failures(pr_number, repo_owner, repo_name, api_token)
                  'No failures'
                end
              end
            RUBY
            File.write(custom_adapter_file, custom_adapter_code)

            result = described_class.build_status('123', 'owner', 'repo', 'token')
            expect(result).to eq('custom_success')
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
              'ci' => {
                'source' => 'custom'
              }
            }
            File.write(config_file, config_data.to_yaml)

            expect do
              described_class.build_status('123', 'owner', 'repo', 'token')
            end.to raise_error(/class_name is required/)
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
              'ci' => {
                'source' => 'custom',
                'class_name' => 'NonExistentAdapter'
              }
            }
            File.write(config_file, config_data.to_yaml)

            expect do
              described_class.build_status('123', 'owner', 'repo', 'token')
            end.to raise_error(/Custom adapter file not found/)
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
              'ci' => {
                'source' => 'custom',
                'class_name' => 'IncompleteCiAdapter'
              }
            }
            File.write(config_file, config_data.to_yaml)

            # Create adapter file without required methods
            adapter_file = File.join(wralph_dir, 'incomplete_ci_adapter.rb')
            File.write(adapter_file, 'class IncompleteCiAdapter; end')

            expect { described_class.build_status('123', 'owner', 'repo', 'token') }.to raise_error(/must implement/)
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
              'ci' => {
                'source' => 'unknown_source'
              }
            }
            File.write(config_file, config_data.to_yaml)

            expect { described_class.build_status('123', 'owner', 'repo', 'token') }.to raise_error(/Unknown CI source/)
          end
        end
      end
    end
  end

  describe '.wait_for_build' do
    it 'delegates to the configured adapter' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          wralph_dir = File.join(tmpdir, '.wralph')
          FileUtils.mkdir_p(wralph_dir)
          config_file = File.join(wralph_dir, 'config.yaml')

          config_data = {
            'ci' => {
              'source' => 'circle_ci'
            }
          }
          File.write(config_file, config_data.to_yaml)

          allow(Wralph::Adapters::Cis::CircleCi).to receive(:wait_for_build).and_return(true)

          result = described_class.wait_for_build('123', 'owner', 'repo', 'token')
          expect(result).to be true
          expect(Wralph::Adapters::Cis::CircleCi).to have_received(:wait_for_build).with('123', 'owner', 'repo',
                                                                                         'token')
        end
      end
    end
  end

  describe '.build_failures' do
    it 'delegates to the configured adapter' do
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        Dir.chdir(tmpdir) do
          wralph_dir = File.join(tmpdir, '.wralph')
          FileUtils.mkdir_p(wralph_dir)
          config_file = File.join(wralph_dir, 'config.yaml')

          config_data = {
            'ci' => {
              'source' => 'circle_ci'
            }
          }
          File.write(config_file, config_data.to_yaml)

          allow(Wralph::Adapters::Cis::CircleCi).to receive(:build_failures).and_return('No failures')

          result = described_class.build_failures('123', 'owner', 'repo', 'token')
          expect(result).to eq('No failures')
          expect(Wralph::Adapters::Cis::CircleCi).to have_received(:build_failures).with('123', 'owner', 'repo', 'token')
        end
      end
    end
  end
end
