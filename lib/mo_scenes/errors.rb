# frozen_string_literal: true

module MoScenes
  class Error < StandardError; end

  class SceneNotLoadedError < Error; end

  class RecordNotFoundError < Error; end

  class SceneDefinitionError < Error; end
end
