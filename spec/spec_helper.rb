# frozen_string_literal: true

require "minitest/autorun"
require "active_record"
require "mo_scenes"

require_relative "dummy/config/application"
require_relative "dummy/app/models/user"
require_relative "dummy/app/models/project"
require_relative "dummy/app/models/todo"

module SceneTestSetup
  def setup_mo_scenes(scenes_path: nil)
    MoScenes.reset!
    path = scenes_path || File.join(__dir__, "dummy", "test", "scenes")
    MoScenes.configure do |config|
      config.scenes_path = path
    end
  end
end
