# frozen_string_literal: true

require_relative "mo_scenes/version"
require_relative "mo_scenes/errors"
require_relative "mo_scenes/configuration"
require_relative "mo_scenes/scene_result"
require_relative "mo_scenes/registry"
require_relative "mo_scenes/scene"
require_relative "mo_scenes/runner"
require_relative "mo_scenes/test_helper"
require_relative "mo_scenes/seed_helper"

module MoScenes
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def registry
      @registry ||= Registry.new
    end

    def runner
      @runner ||= Runner.new(registry: registry, configuration: configuration)
    end

    def reset!
      @runner&.rollback_global_transaction!
      @configuration = nil
      @registry = nil
      @runner = nil
      @seed_runner = nil
    end
  end
end

require_relative "mo_scenes/railtie" if defined?(Rails::Railtie)
