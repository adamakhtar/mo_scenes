# frozen_string_literal: true

# Invoked in a subprocess by global_scene_failure_spec — not part of the normal suite.
require "active_record"
require "mo_scenes/rspec"

require_relative "../../dummy/config/application"
require_relative "../../dummy/app/models/user"
require_relative "../../dummy/app/models/project"
require_relative "../../dummy/app/models/todo"

MoScenes.reset!
MoScenes.configure { |c| c.scenes_path = File.join(__dir__, "..", "..", "dummy", "test", "scenes") }

MoScenes.runner.define_singleton_method(:run_global_scenes!) do
  raise StandardError, "boom"
end

MoScenes::RSpec.install!(RSpec.configuration)

RSpec.describe "suite abort fixture" do
  include MoScenes::RSpecHelper

  it "this example must not run" do
    fail "expected suite hook failure before examples execute"
  end
end
