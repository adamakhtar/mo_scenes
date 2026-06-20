# frozen_string_literal: true

require "spec_helper"
require "mo_scenes/test_helper"

class IntegrationSpec < Minitest::Test
  include SceneTestSetup
  include MoScenes::TestHelper
  prepend MoScenesTestReset

  def teardown
    super
    MoScenes.reset!
    [Todo, Project, User].each(&:delete_all)
  end

  def test_global_scenes_are_loaded
    assert MoScenes.runner.global_loaded?
  end

  def test_accessor_returns_correct_record
    user = users(:admin)
    assert_instance_of User, user
    assert_equal "Admin", user.name
    assert_equal "admin", user.role
  end

  def test_accessor_returns_multiple_records
    admin, member = users(:admin, :member)
    assert_equal "Admin", admin.name
    assert_equal "Member", member.name
  end

  def test_cross_scene_references_work
    project = small_project(:project)
    admin = users(:admin)
    assert_equal admin.id, project.user_id
  end

  def test_accessor_caches_by_default
    project1 = small_project(:project)
    project2 = small_project(:project)
    assert_equal project1.id, project2.id
    assert_equal project1.object_id, project2.object_id
  end

  def test_reload_flag_forces_fresh_db_read
    project = small_project(:project)
    original_object_id = project.object_id

    reloaded = small_project(:project, reload: true)
    assert_equal project.id, reloaded.id
    refute_equal original_object_id, reloaded.object_id
  end

  def test_invalid_record_name_raises_with_available
    err = assert_raises(MoScenes::RecordNotFoundError) { users(:nonexistent) }
    assert_includes err.message, ":nonexistent"
    assert_includes err.message, ":admin"
  end

  def test_per_test_scene_load_and_access
    load_scene(:large_project)
    project = large_project(:project)
    assert_equal "Large Project", project.name
    assert_equal 15, project.todos.count
  end

  def test_scene_data_persists_across_accessor_calls
    todo = small_project(:shopping_todo)
    project = small_project(:project)
    assert_equal project.id, todo.project_id
  end

  def test_modifications_in_test_visible_with_reload
    project = small_project(:project)
    project.update!(name: "Modified")

    fresh = small_project(:project, reload: true)
    assert_equal "Modified", fresh.name
  end

  def test_in_memory_mutations_do_not_leak_across_test_instances
    MoScenes.runner.ensure_global_scenes_loaded!

    example_class = Class.new { include MoScenes::TestHelper }
    first_example = example_class.new
    second_example = example_class.new

    project_in_first = first_example.small_project(:project)
    project_in_first.name = "Mutated in memory"

    project_in_second = second_example.small_project(:project)
    assert_equal "Small Project", project_in_second.name
    refute_equal project_in_first.object_id, project_in_second.object_id

    assert_equal "Mutated in memory", first_example.small_project(:project).name
  end
end
