# frozen_string_literal: true

require "spec_helper"
require "mo_scenes/test_helper"

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
