# frozen_string_literal: true

module MoScenes
  # Shared example-level API included by Minitest and RSpec integrations.
  # Dynamic scene accessors (e.g. users) are defined on this module by Runner.
  module ExampleGroupHelper
    def load_scene(name)
      MoScenes.runner.load_scene(name)
    end
  end
end
