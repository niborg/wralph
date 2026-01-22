# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Wralph::Interfaces::Agent do
  describe '.run' do
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
end
