# frozen_string_literal: true

require_relative '../adapters/agent'

module Wralph
  module Interfaces
    module Agent
      def self.run(instructions)
        Adapters::Agent::ClaudeCode.run(instructions)
      end
    end
  end
end
