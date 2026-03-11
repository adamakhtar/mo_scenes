# frozen_string_literal: true

require "spec_helper"

class RunnerSpec < Minitest::Test
  include SceneTestSetup

  def setup
    setup_mo_scenes
  end

  def teardown
    MoScenes.reset!
    [Todo, Project, User].each(&:delete_all)
  end

  def test_ensure_global_scenes_loaded_is_idempotent
    MoScenes.runner.ensure_global_scenes_loaded!
    user_count = User.count

    MoScenes.runner.ensure_global_scenes_loaded!
    assert_equal user_count, User.count
  end

  def test_rollback_global_transaction_cleans_db
    MoScenes.runner.ensure_global_scenes_loaded!
    assert User.count > 0

    MoScenes.runner.rollback_global_transaction!
    assert_equal 0, User.count
  end

  def test_scene_files_loaded_in_sorted_order
    MoScenes.runner.ensure_global_scenes_loaded!

    assert MoScenes.registry.scene?(:users)
    assert MoScenes.registry.scene?(:small_project)
    assert MoScenes.registry.scene?(:large_project)
  end

  def test_only_global_scenes_run_on_load
    MoScenes.runner.ensure_global_scenes_loaded!

    assert MoScenes.registry.loaded?(:users)
    assert MoScenes.registry.loaded?(:small_project)
    refute MoScenes.registry.loaded?(:large_project)
  end

  def test_load_scene_runs_per_test_scene
    MoScenes.runner.ensure_global_scenes_loaded!
    MoScenes.runner.load_scene(:large_project)

    assert MoScenes.registry.loaded?(:large_project)
    project = MoScenes.registry.fetch(:large_project, :project)
    assert_equal "Large Project", project.name
  end

  def test_load_scene_unknown_raises
    MoScenes.runner.ensure_global_scenes_loaded!

    err = assert_raises(MoScenes::SceneNotLoadedError) { MoScenes.runner.load_scene(:nonexistent) }
    assert_includes err.message, ":nonexistent"
  end

  def test_scene_returning_non_hash_raises
    MoScenes.runner.load_scene_files!

    bad_class = Class.new(MoScenes::Scene) do
      define_singleton_method(:name) { "BadReturnScene" }
      self.global = false
      define_method(:call) { "not a hash" }
    end
    MoScenes.registry.register(bad_class)

    err = assert_raises(MoScenes::SceneDefinitionError) { MoScenes.runner.load_scene(:bad_return) }
    assert_includes err.message, "must return a Hash"
  end
end
