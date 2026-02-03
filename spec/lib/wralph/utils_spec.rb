# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Wralph::Utils do
  describe '.prompt_sub' do
    it 'substitutes variables in the prompt' do
      prompt = "Hello \#{name}, your issue is #\#{issue_number}"
      variables = {
        name: 'Alice',
        issue_number: 123
      }

      result = Wralph::Utils.prompt_sub(prompt, variables)
      expect(result).to eq('Hello Alice, your issue is #123')
    end

    it 'raises an error when variables are missing' do
      prompt = "Hello \#{name}, your issue is #\#{issue_number} and file is \#{file_path}"
      variables = {
        name: 'Alice',
        issue_number: 123
      }

      expect do
        Wralph::Utils.prompt_sub(prompt, variables)
      end.to raise_error(ArgumentError, /Prompt substitution failed.*file_path/)
    end

    it 'raises an error with all missing variables in the message' do
      prompt = "Vars: \#{a}, \#{b}, \#{c}"
      variables = {a: 'value'}

      expect do
        Wralph::Utils.prompt_sub(prompt, variables)
      end.to raise_error(ArgumentError, /\#\{b\}.*\#\{c\}/)
    end

    it 'returns nil when prompt is nil' do
      result = Wralph::Utils.prompt_sub(nil, {name: 'test'})
      expect(result).to be_nil
    end

    it 'returns the original prompt when variables is nil' do
      prompt = "Hello \#{name}"
      result = Wralph::Utils.prompt_sub(prompt, nil)
      expect(result).to eq(prompt)
    end

    it 'converts variable values to strings' do
      prompt = "Issue #\#{issue_number}"
      variables = {issue_number: 123}

      result = Wralph::Utils.prompt_sub(prompt, variables)
      expect(result).to eq('Issue #123')
    end
  end
end
