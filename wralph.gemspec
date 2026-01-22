# wralph.gemspec
require_relative 'lib/wralph/version' # Ensure this file exists, or hardcode version below

Gem::Specification.new do |spec|
  spec.name          = 'wralph'
  spec.version       = Wralph::VERSION # Or replace with "0.1.0"
  spec.authors       = ['Nick Knipe']
  spec.email         = ['nick@hellodrifter.com']

  spec.summary       = 'Human-In-The-Loop AI Factory'
  spec.description   = 'A CLI that wraps a coding agent and CI to autonomously ' \
                       'complete software objectives using the Ralph Wiggum technique. '
  spec.homepage      = 'https://github.com/niborg/wralph'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  # CRITICAL FOR HOMEBREW: Do not use `git ls-files`
  # We manually tell Ruby which folders to include in the package
  spec.files = Dir['lib/**/*', 'bin/*', 'README.md', 'LICENSE.txt']

  spec.bindir        = 'bin'
  spec.executables   = ['wralph']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'webmock'
end
