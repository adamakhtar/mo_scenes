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

  def test_default_scenes_path_is_nil
    assert_nil MoScenes.configuration.scenes_path
  end
end
