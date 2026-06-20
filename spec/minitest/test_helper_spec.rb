# frozen_string_literal: true

require "spec_helper"
require "mo_scenes/minitest"

class MinitestTestHelperSpec < Minitest::Test
  include SceneTestSetup

  def teardown
    super
    MoScenes.reset!
    [Todo, Project, User].each(&:delete_all)
  end

  def test_including_test_helper_triggers_before_setup_automatically
    test_class = Class.new(Minitest::Test) do
      include SceneTestSetup
      include MoScenes::TestHelper
      prepend MoScenesTestReset

      define_method(:test_loads_global_scenes) do
        assert MoScenes.runner.global_loaded?
      end
    end

    test_class.new(:test_loads_global_scenes).run
    assert MoScenes.runner.global_loaded?
  end

  def test_before_setup_calls_ensure_global_scenes_loaded
    test_class = Class.new(Minitest::Test) do
      include SceneTestSetup
      include MoScenes::TestHelper
      prepend MoScenesTestReset

      define_method(:test_example) { assert true }
    end

    test_class.new(:test_example).run
    assert MoScenes.runner.global_loaded?
  end

  def test_after_teardown_clears_per_test_scenes
    test_class = Class.new(Minitest::Test) do
      include SceneTestSetup
      include MoScenes::TestHelper
      prepend MoScenesTestReset

      define_method(:test_example) do
        load_scene(:large_project)
        assert MoScenes.registry.loaded?(:large_project)
      end
    end

    test_class.new(:test_example).run
    refute MoScenes.registry.loaded?(:large_project)
  end

  def test_global_scenes_run_once_across_multiple_examples
    setup_mo_scenes
    call_count = 0
    runner = MoScenes.runner
    original_run_global = runner.method(:run_global_scenes!)
    runner.define_singleton_method(:run_global_scenes!) do
      call_count += 1
      original_run_global.call
    end

    test_class = Class.new(Minitest::Test) do
      include MoScenes::TestHelper

      define_method(:test_first) { assert_equal "Admin", users(:admin).name }
      define_method(:test_second) { assert_equal "Member", users(:member).name }
    end

    test_class.new(:test_first).run
    test_class.new(:test_second).run

    assert_equal 1, call_count
  end

  def test_latched_global_load_failure_does_not_retry_per_example
    setup_mo_scenes
    run_count = 0
    MoScenes.runner.define_singleton_method(:run_global_scenes!) do
      run_count += 1
      raise "boom"
    end

    body_ran = []
    test_class = Class.new(Minitest::Test) do
      include MoScenes::TestHelper

      define_method(:test_first) { body_ran << :first; flunk "example body should not run" }
      define_method(:test_second) { body_ran << :second; flunk "example body should not run" }
    end

    first = test_class.new(:test_first).run
    second = test_class.new(:test_second).run

    assert_equal 1, run_count
    assert MoScenes.runner.global_load_failed?
    refute first.passed?
    refute second.passed?
    assert_empty body_ran
  end
end

class MinitestSuiteTeardownSpec < Minitest::Test
  include SceneTestSetup

  def setup
    setup_mo_scenes
  end

  def teardown
    MoScenes.reset!
    [Todo, Project, User].each(&:delete_all)
  end

  def test_after_run_rolls_back_global_transaction
    MoScenes.runner.ensure_global_scenes_loaded!
    assert MoScenes.runner.global_loaded?
    assert User.count > 0

    MoScenes.runner.rollback_global_transaction!

    refute MoScenes.runner.global_loaded?
    assert_equal 0, User.count
  end
end
