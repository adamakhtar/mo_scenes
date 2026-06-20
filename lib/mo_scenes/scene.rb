# frozen_string_literal: true

module MoScenes
  # Base class for scene definitions. Subclasses default to global (loaded once
  # before the suite). Set `self.global = false` for scenes loaded per test.
  class Scene
    class << self
      def inherited(subclass)
        super
        # New subclasses are global unless they opt out with self.global = false.
        subclass.instance_variable_set(:@global, true)
        descendants << subclass
      end

      def descendants
        @descendants ||= []
      end

      def reset_descendants!
        @descendants = []
      end

      def global
        @global
      end

      def global=(value)
        @global = value
      end

      def global?
        @global
      end

      # UsersScene -> :users, SmallProjectScene -> :small_project
      def scene_name
        raw = self.name || self.to_s
        underscored = raw.gsub(/::/, "_")
          .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .downcase

        unless underscored.end_with?("_scene")
          raise SceneDefinitionError, "Scene class #{raw} must end with 'Scene' (e.g. #{raw}Scene)"
        end

        underscored.delete_suffix("_scene").to_sym
      end
    end

    def initialize(registry)
      @registry = registry
    end

    def call
      raise NotImplementedError, "#{self.class.name} must implement #call and return a Hash of { name => record }"
    end

    private

    # Cross-scene reference helper: scene(:users).admin
    def scene(name)
      @registry.scene_result(name)
    end
  end
end
