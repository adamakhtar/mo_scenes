# frozen_string_literal: true

require "spec_helper"
require "rails/generators/test_case"
require "generators/mo_scenes/ai_skill/ai_skill_generator"

class AiSkillGeneratorSpec < Rails::Generators::TestCase
  tests MoScenes::Generators::AiSkillGenerator
  destination File.expand_path("tmp/generators", __dir__)

  def setup
    prepare_destination
  end

  def teardown
    FileUtils.rm_rf(destination_root)
  end

  def test_copies_ai_skill_document_to_default_path
    run_generator

    assert_file "docs/ai/mo-scenes-skill.md" do |content|
      assert_includes content, "name: mo-scenes"
      assert_includes content, "## Testing Philosophy"
      assert_includes content, "Prefer existing global scene records"
    end
  end

  def test_accepts_custom_destination_path
    run_generator ["CLAUDE.md"]

    assert_file "CLAUDE.md" do |content|
      assert_includes content, "Use MoScenes in Rails test suites"
    end
  end

  def test_accepts_claude_target
    run_generator ["claude"]

    assert_file ".claude/skills/mo-scenes/SKILL.md" do |content|
      assert_includes content, "name: mo-scenes"
    end
  end

  def test_accepts_cursor_target
    run_generator ["cursor"]

    assert_file ".cursor/rules/mo_scenes.mdc" do |content|
      assert_includes content, "name: mo-scenes"
    end
  end
end
