# frozen_string_literal: true

require 'shellwords'
require_relative '../../config'
require_relative '../../interfaces/shell'

module Wralph
  module Adapters
    module Agents
      module ClaudeCode
        def self.run(instructions)
          flags = Config.load.agent_harness&.flags || ['dangerously-skip-permissions']
          flag_args = Array(flags).map { |f| "--#{f}" }.join(' ')
          command = "claude -p #{Shellwords.shellescape(instructions)} #{flag_args}".strip

          claude_output, = Interfaces::Shell.run_command(command, raise_on_error: false)
          claude_output
        end
      end
    end
  end
end
