# frozen_string_literal: true

require "rails/railtie"

module MoScenes
  class Railtie < Rails::Railtie
    initializer "mo_scenes.set_defaults" do
      MoScenes.configure do |config|
        config.scenes_path ||= Rails.root.join("test", "scenes").to_s
      end
    end

    rake_tasks do
      namespace :db do
        namespace :scenes do
          desc "Load all global scenes into the database"
          task load: :environment do
            MoScenes.load_all
            puts "Scenes loaded."
          end
        end
      end
    end
  end
end
