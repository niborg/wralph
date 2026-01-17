# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Nitl do
  describe 'VERSION' do
    it 'has a version number' do
      expect(Nitl::VERSION).not_to be nil
    end

    it 'is a valid semantic version string' do
      expect(Nitl::VERSION).to match(/\d+\.\d+\.\d+/)
    end
  end
end
