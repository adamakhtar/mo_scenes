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

  def test_global_scene_call_failure_latches_error_without_retry
    runner = MoScenes.runner
    run_count = 0
    txn_count = 0
    original_open = runner.method(:open_global_transaction!)
    runner.define_singleton_method(:run_global_scenes!) do
      run_count += 1
      raise "boom"
    end
    runner.define_singleton_method(:open_global_transaction!) do
      txn_count += 1
      original_open.call
    end

    first = assert_raises(RuntimeError) { runner.ensure_global_scenes_loaded! }
    second = assert_raises(RuntimeError) { runner.ensure_global_scenes_loaded! }

    assert_equal "boom", first.message
    assert_same first, second
    assert runner.global_load_failed?
    refute runner.global_loaded?
    assert_equal 1, run_count
    assert_equal 1, txn_count
  end

  def test_global_scene_call_failure_rolls_back_partial_load
    runner = MoScenes.runner
    runner.load_scene_files!

    runner.define_singleton_method(:run_global_scenes!) do
      registry.global_scene_names.each do |name|
        scene_class = registry.scenes[name]
        result = scene_class.new(registry).call
        validate_scene_result!(name, result)
        registry.store_result(name, result)
        raise "boom after partial load" if name == :users
      end
    end

    assert_raises(RuntimeError) { runner.ensure_global_scenes_loaded! }

    refute runner.global_loaded?
    refute MoScenes.registry.loaded?(:users)
    assert_equal 0, User.count
    assert_equal 0, Project.count
  end

  def test_global_scene_non_hash_failure_latches_without_retry
    runner = MoScenes.runner
    run_count = 0
    runner.define_singleton_method(:run_global_scenes!) do
      run_count += 1
      raise MoScenes::SceneDefinitionError,
        "Scene :bad #call must return a Hash of { name => record }, got String"
    end

    first = assert_raises(MoScenes::SceneDefinitionError) { runner.ensure_global_scenes_loaded! }
    second = assert_raises(MoScenes::SceneDefinitionError) { runner.ensure_global_scenes_loaded! }

    assert_same first, second
    assert_includes first.message, "must return a Hash"
    assert_equal 1, run_count
  end

  def test_reset_clears_latched_global_load_error
    runner = MoScenes.runner
    runner.define_singleton_method(:run_global_scenes!) { raise "boom" }

    assert_raises(RuntimeError) { runner.ensure_global_scenes_loaded! }
    assert runner.global_load_failed?

    MoScenes.reset!
    setup_mo_scenes
    refute MoScenes.runner.global_load_failed?

    MoScenes.runner.ensure_global_scenes_loaded!
    assert MoScenes.runner.global_loaded?
  end
end
