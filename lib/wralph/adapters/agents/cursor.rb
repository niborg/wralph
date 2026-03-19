# frozen_string_literal: true

require 'shellwords'
require_relative '../../config'
require_relative '../../interfaces/shell'

module Wralph
  module Adapters
    module Agents
      module Cursor
        def self.run(instructions)
          flags = Array(Config.load.agent_harness&.flags)
          flag_args = flags.map { |flag| "--#{flag}" }.join(' ')
          command = "agent -p #{Shellwords.shellescape(instructions)} #{flag_args}".strip

          cursor_output, = Interfaces::Shell.run_command(command, raise_on_error: false)
          cursor_output
        end
      end
    end
  end
end
