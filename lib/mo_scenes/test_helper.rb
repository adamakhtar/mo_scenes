# frozen_string_literal: true

require "active_support/concern"

module MoScenes
  # Minitest integration. Prepended SetupTeardown runs before/after each example.
  #
  # before_setup: ensure global scenes + outer transaction (once per process).
  # after_teardown: clear per-test registry entries so load_scene state does not
  #   leak; @scene_cache on each example instance is discarded with the instance.
  module TestHelper
    extend ActiveSupport::Concern

    included do
      prepend SetupTeardown
    end

    module SetupTeardown
      def before_setup
        MoScenes.runner.ensure_global_scenes_loaded!
        super
      end

      def after_teardown
        super
        MoScenes.registry.clear_per_test_scenes!
      end
    end

    def load_scene(name)
      MoScenes.runner.load_scene(name)
    end
  end
end
