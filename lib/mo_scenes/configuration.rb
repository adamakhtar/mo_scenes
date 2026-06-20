# frozen_string_literal: true

module MoScenes
  class Configuration
    def scenes_path
      @scenes_path ||= default_scenes_path
    end

    def scenes_path=(path)
      @scenes_path = path
    end

    private

    def default_scenes_path
      segments = rspec_active? ? %w[spec scenes] : %w[test scenes]

      if defined?(Rails) && Rails.respond_to?(:root)
        Rails.root.join(*segments).to_s
      else
        File.join(*segments)
      end
    end

    def rspec_active?
      defined?(::RSpec) && ::RSpec.respond_to?(:configuration)
    end
  end
end
