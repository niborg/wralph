# frozen_string_literal: true

# Add lib directory to load path for testing
lib_dir = File.expand_path(File.join(__dir__, '..', 'lib'))
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

require 'fileutils'
require 'webmock/rspec'
require 'nitl'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Cleanup any .nitl directories created during tests
  config.after(:suite) do
    repo_root = File.expand_path(File.join(__dir__, '..'))
    nitl_dir = File.join(repo_root, '.nitl')
    if Dir.exist?(nitl_dir)
      FileUtils.rm_rf(nitl_dir)
    end
  end
end
