# frozen_string_literal: true

require "set"

module MoScenes
  # Central store for scene classes and loaded scene data.
  #
  # @loaded_results — SceneResult wrappers returned by #call (used for cross-scene
  #   references via scene(:name) inside other scenes).
  # @pk_map — primary keys per record name; accessors use this for Model.find so
  #   each test gets objects reflecting post-rollback DB state, not objects
  #   captured at load time.
  # @per_test_scenes — names loaded via load_scene; cleared in test teardown
  #   while global scene entries persist for the whole suite.
  class Registry
    attr_reader :scenes

    def initialize
      @scenes = {}
      @loaded_results = {}
      @pk_map = {}
      @per_test_scenes = Set.new
    end

    def register(scene_class)
      name = scene_class.scene_name
      @scenes[name] = scene_class
    end

    # Discover Scene subclasses after require'ing scene files. Skips abstract
    # base (#call still defined on MoScenes::Scene) and invalid definitions.
    def register_descendants!
      MoScenes::Scene.descendants.each do |klass|
        next unless klass.name && !klass.name.empty?
        next if klass.instance_method(:call).owner == MoScenes::Scene

        name = klass.scene_name
        @scenes[name] = klass unless @scenes.key?(name)
      rescue SceneDefinitionError
        next
      end
    end

    def scene_names
      @scenes.keys
    end

    def scene?(name)
      @scenes.key?(name)
    end

    def global_scene_names
      @scenes.select { |_, klass| klass.global? }.keys
    end

    # Persist a scene's #call result. Global scenes are stored once for the suite;
    # per_test: true marks the scene for teardown cleanup (see clear_per_test_scenes!).
    def store_result(scene_name, records_hash, per_test: false)
      result = SceneResult.new(records_hash)
      @loaded_results[scene_name] = result

      @pk_map[scene_name] = {}
      records_hash.each do |record_name, record|
        @pk_map[scene_name][record_name.to_sym] = [record.class, record.public_send(record.class.primary_key)]
      end

      @per_test_scenes.add(scene_name) if per_test
    end

    def scene_result(scene_name)
      @loaded_results.fetch(scene_name) do
        raise SceneNotLoadedError,
          "Scene :#{scene_name} has not been loaded yet. " \
          "Ensure the scene file is numbered to load before scenes that depend on it."
      end
    end

    # Used by fixture-style accessors (users(:admin)). Always hits the DB via
    # Model.find so rolled-back attribute changes from a previous test are not
    # visible — unlike the in-example @scene_cache on TestHelper instances.
    def fetch(scene_name, record_name)
      scene_data = @pk_map.fetch(scene_name) do
        raise SceneNotLoadedError, "Scene :#{scene_name} has not been loaded."
      end

      record_name = record_name.to_sym
      unless scene_data.key?(record_name)
        available = scene_data.keys.map(&:inspect).join(", ")
        raise RecordNotFoundError,
          "Scene :#{scene_name} has no record :#{record_name}. Available records: #{available}"
      end

      model_class, pk = scene_data[record_name]
      model_class.find(pk)
    end

    def loaded?(scene_name)
      @loaded_results.key?(scene_name)
    end

    # Drop per-test scene state between examples. Global scene entries stay loaded
    # for the suite; only @per_test_scenes are removed. DB rows from per-test
    # scenes roll back via the savepoint — this clears in-memory registry state.
    def clear_per_test_scenes!
      @per_test_scenes.each do |name|
        @loaded_results.delete(name)
        @pk_map.delete(name)
      end
      @per_test_scenes.clear
    end

    # Full wipe when the outer global transaction is rolled back (suite teardown).
    def reset!
      @loaded_results.clear
      @pk_map.clear
      @per_test_scenes.clear
    end
  end
end
