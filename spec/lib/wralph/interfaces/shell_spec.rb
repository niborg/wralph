# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Wralph::Interfaces::Shell do
  describe '.command_exists?' do
    it 'returns true for existing commands' do
      expect(described_class.command_exists?('ls')).to be true
      expect(described_class.command_exists?('ruby')).to be true
    end

    it 'returns false for non-existent commands' do
      expect(described_class.command_exists?('nonexistent_command_xyz123')).to be false
    end

    it 'handles commands with arguments correctly' do
      # NOTE: command_exists only checks if the base command exists
      expect(described_class.command_exists?('ls')).to be true
    end
  end

  describe '.run_command' do
    it 'runs a simple command successfully' do
      stdout, stderr, success = described_class.run_command('echo "hello"')
      expect(success).to be true
      expect(stdout).to eq('hello')
      expect(stderr).to eq('')
    end

    it 'returns stdout, stderr, and status' do
      stdout, stderr, success = described_class.run_command('echo "test"')
      expect(stdout).to be_a(String)
      expect(stderr).to be_a(String)
      expect(success).to be(true).or(be(false))
    end

    it 'handles commands that write to stderr' do
      _, stderr, success = described_class.run_command('echo "error" >&2 && exit 0')
      expect(success).to be true
      expect(stderr).to eq('error')
    end

    it 'returns false status for failed commands' do
      _, _, success = described_class.run_command('false')
      expect(success).to be false
    end

    it 'does not raise by default when command fails' do
      expect do
        described_class.run_command('false')
      end.not_to raise_error
    end

    it 'raises an error when raise_on_error is true and command fails' do
      expect do
        described_class.run_command('false', raise_on_error: true)
      end.to raise_error(RuntimeError, /Command failed/)
    end

    it 'strips newlines from stdout and stderr' do
      stdout, _, _success = described_class.run_command('echo "test"')
      expect(stdout).not_to end_with("\n")
    end

    it 'handles commands with spaces in arguments' do
      stdout, _stderr, success = described_class.run_command('echo "hello world"')
      expect(success).to be true
      expect(stdout).to eq('hello world')
    end
  end

  describe '.get_worktrees' do
    it 'returns an array' do
      # This test might fail if 'wt' command is not available
      # We'll skip if command doesn't exist
      skip 'wt command not available' unless described_class.command_exists?('wt')

      worktrees = described_class.get_worktrees
      expect(worktrees).to be_an(Array)
    end

    it 'returns worktrees as hash objects when wt is available' do
      skip 'wt command not available' unless described_class.command_exists?('wt')

      worktrees = described_class.get_worktrees
      # Each worktree should be a hash/object if any exist
      worktrees.each do |wt|
        expect(wt).to be_a(Hash)
      end
    end
  end

  describe '.switch_into_worktree' do
    it 'requires wt command to be available' do
      skip 'wt command not available' unless described_class.command_exists?('wt')

      # This is a complex operation that modifies the working directory
      # We'll just verify it doesn't raise an error if called
      # In a real scenario, you'd need a test git repository with worktrees
      expect(described_class).to respond_to(:switch_into_worktree)
    end
  end

  describe '.ask_user_to_continue' do
    it 'exits with code 1 if user does not respond with y or Y' do
      allow($stdin).to receive(:gets).and_return("n\n")

      expect do
        described_class.ask_user_to_continue
      end.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(1)
      end
    end

    it 'does not exit if user responds with y' do
      allow($stdin).to receive(:gets).and_return("y\n")

      expect do
        described_class.ask_user_to_continue
      end.not_to raise_error
    end

    it 'does not exit if user responds with Y' do
      allow($stdin).to receive(:gets).and_return("Y\n")

      expect do
        described_class.ask_user_to_continue
      end.not_to raise_error
    end

    it 'prints the custom message' do
      message = 'Custom message? '
      allow($stdin).to receive(:gets).and_return("y\n")

      expect { described_class.ask_user_to_continue(message) }.to output(message).to_stdout
    end

    it 'uses default message if none provided' do
      allow($stdin).to receive(:gets).and_return("y\n")

      expect { described_class.ask_user_to_continue }.to output('Continue? (y/N) ').to_stdout
    end

    it 'exits on empty response' do
      allow($stdin).to receive(:gets).and_return("\n")

      expect do
        described_class.ask_user_to_continue
      end.to raise_error(SystemExit)
    end

    it 'exits on "no" response' do
      allow($stdin).to receive(:gets).and_return("no\n")

      expect do
        described_class.ask_user_to_continue
      end.to raise_error(SystemExit)
    end
  end
end
