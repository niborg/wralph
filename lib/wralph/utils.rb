# frozen_string_literal: true

module Wralph
  module Utils
    def self.prompt_sub(prompt, variables)
      return prompt if prompt.nil? || variables.nil?

      result = prompt
      variables.each do |key, value|
        result = result.gsub("\#{#{key}}", value.to_s)
      end

      # Check for any remaining unsubstituted variables
      remaining = result.scan(/\#\{\w+\}/)
      raise ArgumentError, "Prompt substitution failed: missing variables #{remaining.join(', ')}" unless remaining.empty?

      result
    end
  end
end
