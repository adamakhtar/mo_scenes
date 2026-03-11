# frozen_string_literal: true

require "spec_helper"

class SceneSpec < Minitest::Test
  def test_scene_name_derivation_simple
    klass = Class.new(MoScenes::Scene)
    klass.define_singleton_method(:name) { "UsersScene" }
    assert_equal :users, klass.scene_name
  end

  def test_scene_name_derivation_multiword
    klass = Class.new(MoScenes::Scene)
    klass.define_singleton_method(:name) { "SmallProjectScene" }
    assert_equal :small_project, klass.scene_name
  end

  def test_scene_name_requires_scene_suffix
    klass = Class.new(MoScenes::Scene)
    klass.define_singleton_method(:name) { "Users" }
    assert_raises(MoScenes::SceneDefinitionError) { klass.scene_name }
  end

  def test_global_defaults_to_true
    klass = Class.new(MoScenes::Scene)
    assert klass.global?
  end

  def test_global_can_be_set_to_false
    klass = Class.new(MoScenes::Scene)
    klass.global = false
    refute klass.global?
  end

  def test_call_raises_not_implemented
    scene = MoScenes::Scene.new(MoScenes.registry)
    assert_raises(NotImplementedError) { scene.call }
  end

  def test_inherited_tracks_descendants
    initial_count = MoScenes::Scene.descendants.size
    Class.new(MoScenes::Scene)
    assert_equal initial_count + 1, MoScenes::Scene.descendants.size
  end
end
