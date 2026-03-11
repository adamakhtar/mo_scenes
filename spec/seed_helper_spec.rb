# frozen_string_literal: true

require "spec_helper"

class SeedHelperSpec < Minitest::Test
  include SceneTestSetup

  def setup
    setup_mo_scenes
  end

  def teardown
    MoScenes.reset!
    [Todo, Project, User].each(&:delete_all)
  end

  def test_load_all
    MoScenes.load_all
    assert User.count > 0
    assert Project.count > 0
  end

  def test_load_only
    MoScenes.load_only(:users)
    assert User.count > 0
    assert_equal 0, Project.count
  end

  def test_load_without
    MoScenes.load_without(:small_project)
    assert User.count > 0
    assert_equal 0, Project.count
  end

  def test_load_only_unknown_scene_raises
    err = assert_raises(MoScenes::SceneNotLoadedError) { MoScenes.load_only(:nonexistent) }
    assert_includes err.message, ":nonexistent"
  end

  def test_seeds_commit_to_db
    MoScenes.load_all
    user_count = User.count
    assert user_count > 0

    # Records are committed (not in a transaction), so they persist
    assert_equal user_count, User.count
  end
end
