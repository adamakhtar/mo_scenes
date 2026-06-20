# frozen_string_literal: true

require "active_record"
require "mo_scenes/rspec"

require_relative "../dummy/config/application"
require_relative "../dummy/app/models/user"
require_relative "../dummy/app/models/project"
require_relative "../dummy/app/models/todo"
require_relative "support/scenes_path"
require_relative "support/mo_scenes"

RSpec.configure { |config| MoScenesRSpecSupport.install!(config) }

RSpec.describe "MoScenes RSpec global scene execution" do
  tracker = { count: 0 }

  before(:all) do
    MoScenes.reset!
    MoScenes.configure { |c| c.scenes_path = SCENES_PATH }

    runner = MoScenes.runner
    original = runner.method(:run_global_scenes!)
    runner.define_singleton_method(:run_global_scenes!) do
      tracker[:count] += 1
      original.call
    end
  end

  after(:all) do
    expect(tracker[:count]).to eq(1)
    MoScenes.reset!
    [Todo, Project, User].each(&:delete_all)
  end

  include MoScenes::RSpecHelper

  it "loads global scenes in the first example" do
    expect(users(:admin).name).to eq("Admin")
  end

  it "reuses global scenes in the second example" do
    expect(users(:member).name).to eq("Member")
  end
end
