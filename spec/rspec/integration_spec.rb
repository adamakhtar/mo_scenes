# frozen_string_literal: true

require "active_record"
require "mo_scenes/rspec"

require_relative "../dummy/config/application"
require_relative "../dummy/app/models/user"
require_relative "../dummy/app/models/project"
require_relative "../dummy/app/models/todo"

SCENES_PATH = File.expand_path("../dummy/test/scenes", __dir__)

RSpec.configure do |config|
  MoScenes::RSpec.install!(config)

  config.prepend_before(:each) do
    MoScenes.reset!
    MoScenes.configure { |c| c.scenes_path = SCENES_PATH }
    [Todo, Project, User].each(&:delete_all)
  end

  config.append_after(:each) do
    MoScenes.reset!
    [Todo, Project, User].each(&:delete_all)
  end
end

RSpec.describe "MoScenes RSpec integration" do
  it "loads global scenes" do
    expect(MoScenes.runner.global_loaded?).to be true
  end

  it "returns correct record via accessor" do
    user = users(:admin)
    expect(user).to be_a(User)
    expect(user.name).to eq("Admin")
    expect(user.role).to eq("admin")
  end

  it "returns multiple records" do
    admin, member = users(:admin, :member)
    expect(admin.name).to eq("Admin")
    expect(member.name).to eq("Member")
  end

  it "supports cross-scene references" do
    project = small_project(:project)
    admin = users(:admin)
    expect(project.user_id).to eq(admin.id)
  end

  it "caches accessor results" do
    project1 = small_project(:project)
    project2 = small_project(:project)
    expect(project1.object_id).to eq(project2.object_id)
  end

  it "reloads with reload: true" do
    project = small_project(:project)
    original_object_id = project.object_id

    reloaded = small_project(:project, reload: true)
    expect(reloaded.id).to eq(project.id)
    expect(reloaded.object_id).not_to eq(original_object_id)
  end

  it "raises on invalid record name" do
    expect { users(:nonexistent) }.to raise_error(MoScenes::RecordNotFoundError) do |error|
      expect(error.message).to include(":nonexistent")
      expect(error.message).to include(":admin")
    end
  end

  it "loads per-test scenes" do
    load_scene(:large_project)
    project = large_project(:project)
    expect(project.name).to eq("Large Project")
    expect(project.todos.count).to eq(15)
  end

  it "persists scene data across accessor calls" do
    todo = small_project(:shopping_todo)
    project = small_project(:project)
    expect(todo.project_id).to eq(project.id)
  end

  it "shows modifications with reload" do
    project = small_project(:project)
    project.update!(name: "Modified")

    fresh = small_project(:project, reload: true)
    expect(fresh.name).to eq("Modified")
  end

  it "does not leak in-memory mutations across example instances" do
    MoScenes.runner.ensure_global_scenes_loaded!

    example_class = Class.new { include MoScenes::RSpecHelper }
    first_example = example_class.new
    second_example = example_class.new

    project_in_first = first_example.small_project(:project)
    project_in_first.name = "Mutated in memory"

    project_in_second = second_example.small_project(:project)
    expect(project_in_second.name).to eq("Small Project")
    expect(project_in_second.object_id).not_to eq(project_in_first.object_id)

    expect(first_example.small_project(:project).name).to eq("Mutated in memory")
  end
end
