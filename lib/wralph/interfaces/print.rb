# frozen_string_literal: true

module Wralph
  module Interfaces
    module Print
      # Colors for output
      module Colors
        RED = "\033[0;31m"
        GREEN = "\033[0;32m"
        YELLOW = "\033[1;33m"
        BLUE = "\033[0;34m"
        NC = "\033[0m" # No Color
      end

      def self.info(msg)
        puts "#{Colors::BLUE}ℹ#{Colors::NC} #{msg}"
      end

      def self.success(msg)
        puts "#{Colors::GREEN}✓#{Colors::NC} #{msg}"
      end

      def self.warning(msg)
        puts "#{Colors::YELLOW}⚠#{Colors::NC} #{msg}"
      end

      def self.error(msg)
        puts "#{Colors::RED}✗#{Colors::NC} #{msg}"
      end
    end
  end
end
