# frozen_string_literal: true

require_relative 'wralph/version'
require_relative 'wralph/config'
require_relative 'wralph/interfaces/repo'
require_relative 'wralph/interfaces/print'
require_relative 'wralph/interfaces/shell'
require_relative 'wralph/interfaces/agent'
require_relative 'wralph/interfaces/ci'
require_relative 'wralph/interfaces/objective_repository'
require_relative 'wralph/run/init'
require_relative 'wralph/run/plan'
require_relative 'wralph/run/execute_plan'
require_relative 'wralph/run/iterate_ci'
require_relative 'wralph/run/feedback'
require_relative 'wralph/run/remove'

module Wralph
end
