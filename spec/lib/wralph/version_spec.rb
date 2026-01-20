# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Wralph do
  describe 'VERSION' do
    it 'has a version number' do
      expect(Wralph::VERSION).not_to be nil
    end

    it 'is a valid semantic version string' do
      expect(Wralph::VERSION).to match(/\d+\.\d+\.\d+/)
    end
  end
end
