# frozen_string_literal: true

require "active_record"

module MoScenes
  class Runner
    attr_reader :registry, :configuration

    def initialize(registry:, configuration:)
      @registry = registry
      @configuration = configuration
      @global_loaded = false
      @transaction_open = false
    end

    def ensure_global_scenes_loaded!
      return if @global_loaded

      load_scene_files!
      open_global_transaction!
      run_global_scenes!
      define_accessor_methods!
      @global_loaded = true
    end

    def load_scene(name)
      load_scene_files!

      scene_class = registry.scenes.fetch(name) do
        raise SceneNotLoadedError, "No scene registered with name :#{name}."
      end

      result = scene_class.new(registry).call
      validate_scene_result!(name, result)
      registry.store_result(name, result, per_test: true)
      define_single_accessor_method!(name)
    end

    def rollback_global_transaction!
      return unless @transaction_open

      ActiveRecord::Base.connection.rollback_transaction
      @transaction_open = false
      @global_loaded = false
      registry.reset!
    end

    def global_loaded?
      @global_loaded
    end

    def load_scene_files!
      return if @files_loaded

      scenes_path = configuration.scenes_path
      if scenes_path && Dir.exist?(scenes_path)
        files = Dir.glob(File.join(scenes_path, "*_scene.rb")).sort
        files.each { |f| require f }
      end

      registry.register_descendants!
      @files_loaded = true
    end

    private

    def open_global_transaction!
      ActiveRecord::Base.connection.begin_transaction(joinable: false)
      @transaction_open = true
    end

    def run_global_scenes!
      registry.global_scene_names.each do |name|
        scene_class = registry.scenes[name]
        result = scene_class.new(registry).call
        validate_scene_result!(name, result)
        registry.store_result(name, result)
      end
    end

    def validate_scene_result!(name, result)
      unless result.is_a?(Hash)
        raise SceneDefinitionError,
          "Scene :#{name} #call must return a Hash of { name => record }, got #{result.class}"
      end
    end

    def define_accessor_methods!
      registry.scene_names.each do |scene_name|
        define_single_accessor_method!(scene_name)
      end
    end

    def define_single_accessor_method!(scene_name)
      return if MoScenes::TestHelper.method_defined?(scene_name)

      MoScenes::TestHelper.define_method(scene_name) do |*record_names, reload: false|
        @scene_cache ||= {}
        @scene_cache[scene_name] ||= {}
        results = record_names.map do |rn|
          @scene_cache[scene_name].delete(rn) if reload
          @scene_cache[scene_name][rn] ||= MoScenes.registry.fetch(scene_name, rn)
        end
        results.size == 1 ? results.first : results
      end
    end
  end
end
