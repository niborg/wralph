# frozen_string_literal: true

require_relative '../adapters/agents'

module Wralph
  module Interfaces
    module Agent
      def self.run(instructions)
        Adapters::Agents::ClaudeCode.run(instructions)
      end
    end
  end
end
