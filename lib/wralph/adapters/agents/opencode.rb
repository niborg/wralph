# frozen_string_literal: true

require 'shellwords'
require_relative '../../interfaces/shell'

module Wralph
  module Adapters
    module Agents
      module Opencode
        def self.run(instructions)
          opencode_output, = Interfaces::Shell.run_command(
            "opencode run --command #{Shellwords.shellescape(instructions)}", raise_on_error: false
          )
          opencode_output
        end
      end
    end
  end
end
