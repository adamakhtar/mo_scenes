# frozen_string_literal: true

require "active_support/concern"
require "minitest"
require_relative "../example_group_helper"

module MoScenes
  module Minitest
    # Minitest integration. Prepended SetupTeardown runs before/after each example.
    #
    # before_setup: ensure global scenes + outer transaction (once per process).
    # after_teardown: clear per-test registry entries so load_scene state does not
    #   leak; @scene_cache on each example instance is discarded with the instance.
    module TestHelper
      extend ActiveSupport::Concern
      include ExampleGroupHelper

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
    end
  end

  TestHelper = Minitest::TestHelper
end

Minitest.after_run { MoScenes.runner.rollback_global_transaction! }
