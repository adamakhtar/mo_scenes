# frozen_string_literal: true

require "spec_helper"

class RegistrySpec < Minitest::Test
  include SceneTestSetup

  def setup
    setup_mo_scenes
    @registry = MoScenes.registry
  end

  def teardown
    MoScenes.reset!
    [Todo, Project, User].each(&:delete_all)
  end

  def test_register_and_scene_names
    klass = Class.new(MoScenes::Scene)
    klass.define_singleton_method(:name) { "ExampleRegScene" }
    @registry.register(klass)

    assert_includes @registry.scene_names, :example_reg
  end

  def test_scene_query
    klass = Class.new(MoScenes::Scene)
    klass.define_singleton_method(:name) { "ExampleQueryScene" }
    @registry.register(klass)

    assert @registry.scene?(:example_query)
    refute @registry.scene?(:nonexistent)
  end

  def test_store_and_fetch
    user = User.create!(name: "Test")
    klass = Class.new(MoScenes::Scene)
    klass.define_singleton_method(:name) { "FetchTestScene" }
    @registry.register(klass)
    @registry.store_result(:fetch_test, { user: user })

    fetched = @registry.fetch(:fetch_test, :user)
    assert_equal user.id, fetched.id
    assert_instance_of User, fetched
  end

  def test_fetch_invalid_record_name
    user = User.create!(name: "Test")
    klass = Class.new(MoScenes::Scene)
    klass.define_singleton_method(:name) { "FetchErrScene" }
    @registry.register(klass)
    @registry.store_result(:fetch_err, { user: user })

    err = assert_raises(MoScenes::RecordNotFoundError) { @registry.fetch(:fetch_err, :nonexistent) }
    assert_includes err.message, ":nonexistent"
    assert_includes err.message, ":user"
  end

  def test_fetch_unloaded_scene
    err = assert_raises(MoScenes::SceneNotLoadedError) { @registry.fetch(:never_loaded, :anything) }
    assert_includes err.message, ":never_loaded"
  end

  def test_scene_result_returns_in_memory_objects
    user = User.create!(name: "InMemory")
    klass = Class.new(MoScenes::Scene)
    klass.define_singleton_method(:name) { "InMemRegScene" }
    @registry.register(klass)
    @registry.store_result(:in_mem_reg, { user: user })

    result = @registry.scene_result(:in_mem_reg)
    assert_equal user.object_id, result.user.object_id
  end

  def test_scene_result_unloaded_raises
    err = assert_raises(MoScenes::SceneNotLoadedError) { @registry.scene_result(:missing) }
    assert_includes err.message, ":missing"
  end

  def test_global_scene_names
    global_klass = Class.new(MoScenes::Scene)
    global_klass.define_singleton_method(:name) { "GlobalRegScene" }
    @registry.register(global_klass)

    non_global_klass = Class.new(MoScenes::Scene)
    non_global_klass.define_singleton_method(:name) { "NonGlobalRegScene" }
    non_global_klass.global = false
    @registry.register(non_global_klass)

    globals = @registry.global_scene_names
    assert_includes globals, :global_reg
    refute_includes globals, :non_global_reg
  end

  def test_per_test_scene_cleanup
    user = User.create!(name: "PerTest")
    klass = Class.new(MoScenes::Scene)
    klass.define_singleton_method(:name) { "PerTestCleanScene" }
    @registry.register(klass)
    @registry.store_result(:per_test_clean, { user: user }, per_test: true)

    assert @registry.loaded?(:per_test_clean)
    @registry.clear_per_test_scenes!
    refute @registry.loaded?(:per_test_clean)
  end

  def test_global_scenes_survive_per_test_cleanup
    user = User.create!(name: "Global")
    klass1 = Class.new(MoScenes::Scene)
    klass1.define_singleton_method(:name) { "PersistRegScene" }
    @registry.register(klass1)
    @registry.store_result(:persist_reg, { user: user })

    per_test_user = User.create!(name: "Temp")
    klass2 = Class.new(MoScenes::Scene)
    klass2.define_singleton_method(:name) { "TempRegScene" }
    @registry.register(klass2)
    @registry.store_result(:temp_reg, { user: per_test_user }, per_test: true)

    @registry.clear_per_test_scenes!

    assert @registry.loaded?(:persist_reg)
    refute @registry.loaded?(:temp_reg)
  end

  def test_register_descendants
    Class.new(MoScenes::Scene) do
      define_singleton_method(:name) { "DescRegScene" }
      define_method(:call) { {} }
    end

    new_registry = MoScenes::Registry.new
    new_registry.register_descendants!

    assert new_registry.scene?(:desc_reg)
  end
end
