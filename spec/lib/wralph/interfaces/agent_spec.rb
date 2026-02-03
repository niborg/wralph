# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Wralph::Interfaces::Agent do
  before do
    described_class.reset_adapter
  end

  describe '.run with claude_code adapter (default)' do
    before do
      allow(Wralph::Config).to receive(:load).and_return(
        OpenStruct.new(
          agent_harness: OpenStruct.new(source: 'claude_code')
        )
      )
    end

    it 'calls claude with the provided instructions' do
      instructions = 'Test instructions'
      expected_command = /claude -p.*--dangerously-skip-permissions/

      allow(Wralph::Interfaces::Shell).to receive(:run_command).and_return(['test output', '', true])

      described_class.run(instructions)

      expect(Wralph::Interfaces::Shell).to have_received(:run_command) do |cmd|
        expect(cmd).to match(expected_command)
        expect(cmd).to include('--dangerously-skip-permissions')
      end
    end

    it 'returns the stdout output from claude' do
      expected_output = 'AI generated response'
      allow(Wralph::Interfaces::Shell).to receive(:run_command).and_return([expected_output, '', true])

      result = described_class.run('test instructions')

      expect(result).to eq(expected_output)
    end

    it 'shell-escapes the instructions to prevent command injection' do
      malicious_instructions = 'test; rm -rf /'
      allow(Wralph::Interfaces::Shell).to receive(:run_command).and_return(['safe', '', true])

      described_class.run(malicious_instructions)

      expect(Wralph::Interfaces::Shell).to have_received(:run_command) do |cmd|
        # The command should contain the escaped instructions
        # Shellwords.shellescape should have escaped the semicolon and other special chars
        expect(cmd).to match(/claude -p/)
        expect(cmd).not_to include('; rm -rf')
      end
    end

    it 'handles instructions with quotes and special characters' do
      instructions = 'test "quoted" instructions with $variables'
      allow(Wralph::Interfaces::Shell).to receive(:run_command).and_return(['output', '', true])

      expect do
        described_class.run(instructions)
      end.not_to raise_error

      expect(Wralph::Interfaces::Shell).to have_received(:run_command)
    end

    it 'handles multiline instructions' do
      instructions = "Line 1\nLine 2\nLine 3"
      allow(Wralph::Interfaces::Shell).to receive(:run_command).and_return(['output', '', true])

      expect do
        described_class.run(instructions)
      end.not_to raise_error

      expect(Wralph::Interfaces::Shell).to have_received(:run_command)
    end

    it 'handles empty instructions' do
      allow(Wralph::Interfaces::Shell).to receive(:run_command).and_return(['output', '', true])

      expect do
        described_class.run('')
      end.not_to raise_error

      expect(Wralph::Interfaces::Shell).to have_received(:run_command)
    end

    it 'does not raise on error by default' do
      allow(Wralph::Interfaces::Shell).to receive(:run_command).and_return(['error output', 'stderr', false])

      expect do
        result = described_class.run('instructions')
        expect(result).to eq('error output')
      end.not_to raise_error
    end

    it 'uses raise_on_error: false when calling run_command' do
      allow(Wralph::Interfaces::Shell).to receive(:run_command).and_return(['output', '', true])

      described_class.run('instructions')

      expect(Wralph::Interfaces::Shell).to have_received(:run_command) do |_cmd, options|
        expect(options[:raise_on_error]).to be false
      end
    end

    it 'handles very long instructions' do
      long_instructions = 'a' * 10_000
      allow(Wralph::Interfaces::Shell).to receive(:run_command).and_return(['output', '', true])

      expect do
        described_class.run(long_instructions)
      end.not_to raise_error

      expect(Wralph::Interfaces::Shell).to have_received(:run_command)
    end
  end

  describe '.run with opencode adapter' do
    before do
      allow(Wralph::Config).to receive(:load).and_return(
        OpenStruct.new(
          agent_harness: OpenStruct.new(source: 'opencode')
        )
      )
    end

    it 'calls opencode with the provided instructions' do
      instructions = 'Test instructions'
      expected_command = /opencode run --command/

      allow(Wralph::Interfaces::Shell).to receive(:run_command).and_return(['test output', '', true])

      described_class.run(instructions)

      expect(Wralph::Interfaces::Shell).to have_received(:run_command) do |cmd|
        expect(cmd).to match(expected_command)
      end
    end

    it 'returns the stdout output from opencode' do
      expected_output = 'AI generated response'
      allow(Wralph::Interfaces::Shell).to receive(:run_command).and_return([expected_output, '', true])

      result = described_class.run('test instructions')

      expect(result).to eq(expected_output)
    end

    it 'shell-escapes the instructions to prevent command injection' do
      malicious_instructions = 'test; rm -rf /'
      allow(Wralph::Interfaces::Shell).to receive(:run_command).and_return(['safe', '', true])

      described_class.run(malicious_instructions)

      expect(Wralph::Interfaces::Shell).to have_received(:run_command) do |cmd|
        expect(cmd).to match(/opencode run --command/)
        expect(cmd).not_to include('; rm -rf')
      end
    end

    it 'uses raise_on_error: false when calling run_command' do
      allow(Wralph::Interfaces::Shell).to receive(:run_command).and_return(['output', '', true])

      described_class.run('instructions')

      expect(Wralph::Interfaces::Shell).to have_received(:run_command) do |_cmd, options|
        expect(options[:raise_on_error]).to be false
      end
    end
  end

  describe '.load_adapter' do
    it 'raises an error for unknown source' do
      allow(Wralph::Config).to receive(:load).and_return(
        OpenStruct.new(
          agent_harness: OpenStruct.new(source: 'unknown_adapter')
        )
      )

      expect { described_class.adapter }.to raise_error(/Unknown agent_harness source/)
    end

    it 'defaults to claude_code when agent_harness is nil' do
      allow(Wralph::Config).to receive(:load).and_return(
        OpenStruct.new(agent_harness: nil)
      )

      adapter = described_class.adapter
      expect(adapter).to eq(Wralph::Adapters::Agents::ClaudeCode)
    end

    it 'defaults to claude_code when source is not specified' do
      allow(Wralph::Config).to receive(:load).and_return(
        OpenStruct.new(
          agent_harness: OpenStruct.new(source: nil)
        )
      )

      adapter = described_class.adapter
      expect(adapter).to eq(Wralph::Adapters::Agents::ClaudeCode)
    end
  end

  describe '.reset_adapter' do
    it 'clears the cached adapter' do
      allow(Wralph::Config).to receive(:load).and_return(
        OpenStruct.new(
          agent_harness: OpenStruct.new(source: 'claude_code')
        )
      )

      # Load adapter first
      first_adapter = described_class.adapter

      # Reset and load again
      described_class.reset_adapter
      second_adapter = described_class.adapter

      # Should be the same class but different instances
      expect(first_adapter).to eq(second_adapter)
    end
  end

  describe 'custom adapter' do
    let(:temp_dir) { Dir.mktmpdir }
    let(:custom_adapter_file) { File.join(temp_dir, 'my_custom_agent.rb') }

    before do
      allow(Wralph::Interfaces::Repo).to receive(:wralph_dir).and_return(temp_dir)

      File.write(custom_adapter_file, <<~RUBY)
        module MyCustomAgent
          def self.run(instructions)
            "Custom: \#{instructions}"
          end
        end
      RUBY
    end

    after do
      FileUtils.rm_rf(temp_dir)
    end

    it 'loads a custom adapter' do
      allow(Wralph::Config).to receive(:load).and_return(
        OpenStruct.new(
          agent_harness: OpenStruct.new(
            source: 'custom',
            class_name: 'MyCustomAgent'
          )
        )
      )

      adapter = described_class.adapter
      expect(adapter).to eq(MyCustomAgent)
    end

    it 'validates the custom adapter interface' do
      invalid_adapter_file = File.join(temp_dir, 'invalid_adapter.rb')
      File.write(invalid_adapter_file, <<~RUBY)
        module InvalidAdapter
          # Missing required run method
        end
      RUBY

      allow(Wralph::Config).to receive(:load).and_return(
        OpenStruct.new(
          agent_harness: OpenStruct.new(
            source: 'custom',
            class_name: 'InvalidAdapter'
          )
        )
      )

      expect { described_class.adapter }.to raise_error(/Custom adapter class must implement: run/)
    end

    it 'raises error when class_name is missing for custom source' do
      allow(Wralph::Config).to receive(:load).and_return(
        OpenStruct.new(
          agent_harness: OpenStruct.new(
            source: 'custom',
            class_name: nil
          )
        )
      )

      expect { described_class.adapter }.to raise_error(/class_name is required/)
    end

    it 'raises error when custom adapter file is not found' do
      allow(Wralph::Config).to receive(:load).and_return(
        OpenStruct.new(
          agent_harness: OpenStruct.new(
            source: 'custom',
            class_name: 'NonExistentAdapter'
          )
        )
      )

      expect { described_class.adapter }.to raise_error(/Custom adapter file not found/)
    end
  end
end
