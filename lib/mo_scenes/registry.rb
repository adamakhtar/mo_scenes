# frozen_string_literal: true

require "set"

module MoScenes
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

    def clear_per_test_scenes!
      @per_test_scenes.each do |name|
        @loaded_results.delete(name)
        @pk_map.delete(name)
      end
      @per_test_scenes.clear
    end

    def reset!
      @loaded_results.clear
      @pk_map.clear
      @per_test_scenes.clear
    end
  end
end
