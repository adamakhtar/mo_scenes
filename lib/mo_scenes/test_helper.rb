# frozen_string_literal: true

require "active_support/concern"

module MoScenes
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
