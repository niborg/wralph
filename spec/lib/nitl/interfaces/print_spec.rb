# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Nitl::Interfaces::Print do
  describe '.info' do
    it 'outputs blue info message with info icon' do
      blue_code = "\033[0;34m"
      reset_code = "\033[0m"
      expected_output = "#{blue_code}ℹ#{reset_code} Test message\n"

      expect { described_class.info('Test message') }.to output(expected_output).to_stdout
    end

    it 'handles empty messages' do
      blue_code = "\033[0;34m"
      reset_code = "\033[0m"
      expected_output = "#{blue_code}ℹ#{reset_code} \n"

      expect { described_class.info('') }.to output(expected_output).to_stdout
    end

    it 'handles multiline messages' do
      blue_code = "\033[0;34m"
      reset_code = "\033[0m"
      message = "Line 1\nLine 2"
      expected_output = "#{blue_code}ℹ#{reset_code} #{message}\n"

      expect { described_class.info(message) }.to output(expected_output).to_stdout
    end
  end

  describe '.success' do
    it 'outputs green success message with checkmark icon' do
      green_code = "\033[0;32m"
      reset_code = "\033[0m"
      expected_output = "#{green_code}✓#{reset_code} Test success\n"

      expect { described_class.success('Test success') }.to output(expected_output).to_stdout
    end

    it 'handles various success messages' do
      green_code = "\033[0;32m"
      reset_code = "\033[0m"
      expected_output = "#{green_code}✓#{reset_code} Operation completed successfully\n"

      expect { described_class.success('Operation completed successfully') }.to output(expected_output).to_stdout
    end
  end

  describe '.warning' do
    it 'outputs yellow warning message with warning icon' do
      yellow_code = "\033[1;33m"
      reset_code = "\033[0m"
      expected_output = "#{yellow_code}⚠#{reset_code} Test warning\n"

      expect { described_class.warning('Test warning') }.to output(expected_output).to_stdout
    end

    it 'handles various warning messages' do
      yellow_code = "\033[1;33m"
      reset_code = "\033[0m"
      expected_output = "#{yellow_code}⚠#{reset_code} This is a warning message\n"

      expect { described_class.warning('This is a warning message') }.to output(expected_output).to_stdout
    end
  end

  describe '.error' do
    it 'outputs red error message with X icon' do
      red_code = "\033[0;31m"
      reset_code = "\033[0m"
      expected_output = "#{red_code}✗#{reset_code} Test error\n"

      expect { described_class.error('Test error') }.to output(expected_output).to_stdout
    end

    it 'handles various error messages' do
      red_code = "\033[0;31m"
      reset_code = "\033[0m"
      expected_output = "#{red_code}✗#{reset_code} An error occurred\n"

      expect { described_class.error('An error occurred') }.to output(expected_output).to_stdout
    end
  end

  describe 'Colors module' do
    it 'defines color constants' do
      expect(described_class::Colors::RED).to eq("\033[0;31m")
      expect(described_class::Colors::GREEN).to eq("\033[0;32m")
      expect(described_class::Colors::YELLOW).to eq("\033[1;33m")
      expect(described_class::Colors::BLUE).to eq("\033[0;34m")
      expect(described_class::Colors::NC).to eq("\033[0m")
    end
  end
end
