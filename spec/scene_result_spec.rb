# frozen_string_literal: true

require "spec_helper"

class SceneResultSpec < Minitest::Test
  def test_dot_access
    result = MoScenes::SceneResult.new(admin: "user_obj", member: "user_obj2")
    assert_equal "user_obj", result.admin
  end

  def test_bracket_access
    result = MoScenes::SceneResult.new(admin: "user_obj")
    assert_equal "user_obj", result[:admin]
  end

  def test_bracket_access_with_string_key
    result = MoScenes::SceneResult.new(admin: "user_obj")
    assert_equal "user_obj", result["admin"]
  end

  def test_missing_key_raises_with_available
    result = MoScenes::SceneResult.new(admin: "a", member: "b")
    err = assert_raises(MoScenes::RecordNotFoundError) { result[:missing] }
    assert_includes err.message, ":admin"
    assert_includes err.message, ":member"
  end

  def test_missing_dot_access_raises
    result = MoScenes::SceneResult.new(admin: "a")
    assert_raises(NoMethodError) { result.nonexistent }
  end

  def test_keys
    result = MoScenes::SceneResult.new(admin: "a", member: "b")
    assert_equal [:admin, :member], result.keys
  end

  def test_to_h
    result = MoScenes::SceneResult.new(admin: "a")
    assert_equal({ admin: "a" }, result.to_h)
  end

  def test_respond_to
    result = MoScenes::SceneResult.new(admin: "a")
    assert result.respond_to?(:admin)
    refute result.respond_to?(:nonexistent)
  end
end
