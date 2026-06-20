# frozen_string_literal: true

require "rails/railtie"

module MoScenes
  class Railtie < Rails::Railtie
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
