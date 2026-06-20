# frozen_string_literal: true

module MoScenes
  class << self
    def load_all
      seed_runner.load_all
    end

    def load_only(*names)
      seed_runner.load_only(*names)
    end

    def load_without(*names)
      seed_runner.load_without(*names)
    end

    private

    def seed_runner
      @seed_runner ||= SeedRunner.new(registry: registry, configuration: configuration)
    end
  end

  # Loads scenes for db:seeds / db:scenes:load. Same scene files and Registry
  # as tests, but no outer transaction — records are committed normally.
  class SeedRunner
    def initialize(registry:, configuration:)
      @registry = registry
      @configuration = configuration
      @files_loaded = false
    end

    def load_all
      load_scene_files!
      run_scenes(@registry.global_scene_names)
    end

    def load_only(*names)
      load_scene_files!
      names = names.flatten.map(&:to_sym)
      missing = names - @registry.scene_names
      if missing.any?
        raise SceneNotLoadedError, "Unknown scene(s): #{missing.map(&:inspect).join(", ")}"
      end
      run_scenes(names)
    end

    def load_without(*names)
      load_scene_files!
      names = names.flatten.map(&:to_sym)
      to_run = @registry.global_scene_names - names
      run_scenes(to_run)
    end

    private

    def load_scene_files!
      return if @files_loaded

      scenes_path = @configuration.scenes_path
      if scenes_path && Dir.exist?(scenes_path)
        files = Dir.glob(File.join(scenes_path, "*_scene.rb")).sort
        files.each { |f| require f }
      end

      @registry.register_descendants!
      @files_loaded = true
    end

    def run_scenes(names)
      names.each do |name|
        scene_class = @registry.scenes.fetch(name) do
          raise SceneNotLoadedError, "No scene registered with name :#{name}."
        end

        result = scene_class.new(@registry).call
        @registry.store_result(name, result) unless @registry.loaded?(name)
      end
    end
  end
end
