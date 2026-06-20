# frozen_string_literal: true

require "spec_helper"

class ConfigurationSpec < Minitest::Test
  def setup
    MoScenes.reset!
  end

  def teardown
    MoScenes.reset!
  end

  def test_configure_block
    MoScenes.configure do |config|
      config.scenes_path = "/custom/path"
    end

    assert_equal "/custom/path", MoScenes.configuration.scenes_path
  end

  def test_default_scenes_path_without_rspec
    config = MoScenes::Configuration.new
    config.define_singleton_method(:rspec_active?) { false }

    assert_equal File.join("test", "scenes"), config.scenes_path
  end

  def test_default_scenes_path_with_rspec
    config = MoScenes::Configuration.new
    config.define_singleton_method(:rspec_active?) { true }

    assert_equal File.join("spec", "scenes"), config.scenes_path
  end

  def test_scenes_path_is_memoized
    config = MoScenes::Configuration.new
    config.define_singleton_method(:rspec_active?) { false }

    first = config.scenes_path
    second = config.scenes_path

    assert_same first, second
  end
end
