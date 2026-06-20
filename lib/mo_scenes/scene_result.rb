# frozen_string_literal: true

module MoScenes
  # Wraps a scene's #call hash. method_missing enables scene(:users).admin
  # dot-access inside other scenes' #call methods.
  class SceneResult
    def initialize(records_hash)
      @records = records_hash.transform_keys(&:to_sym)
    end

    def [](name)
      @records.fetch(name.to_sym) do
        available = @records.keys.map(&:inspect).join(", ")
        raise RecordNotFoundError, "No record :#{name} in this scene. Available: #{available}"
      end
    end

    def method_missing(name, *args)
      if @records.key?(name)
        @records[name]
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      @records.key?(name) || super
    end

    def keys
      @records.keys
    end

    def to_h
      @records.dup
    end
  end
end
