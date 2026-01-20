# frozen_string_literal: true

require 'shellwords'
require_relative '../../interfaces/shell'

module Wralph
  module Adapters
    module Agents
      module ClaudeCode
        def self.run(instructions)
          claude_output, = Interfaces::Shell.run_command(
            "claude -p #{Shellwords.shellescape(instructions)} --dangerously-skip-permissions", raise_on_error: false
          )
          claude_output
        end
      end
    end
  end
end
