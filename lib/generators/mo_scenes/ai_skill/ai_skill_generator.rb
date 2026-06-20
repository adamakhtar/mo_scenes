# frozen_string_literal: true

require "rails/generators"

module MoScenes
  module Generators
    class AiSkillGenerator < Rails::Generators::Base
      source_root File.expand_path("../../../../docs/ai", __dir__)

      desc "Copies the MoScenes AI assistant skill document into your application."

      argument :target,
               type: :string,
               default: "docs/ai/mo-scenes-skill.md",
               banner: "TARGET_OR_DESTINATION_PATH"

      def copy_ai_skill_document
        copy_file "mo-scenes-skill.md", destination_path
      end

      private

      def destination_path
        case target
        when "claude", "claude-code"
          ".claude/skills/mo-scenes/SKILL.md"
        when "cursor"
          ".cursor/rules/mo_scenes.mdc"
        else
          target
        end
      end
    end
  end
end
