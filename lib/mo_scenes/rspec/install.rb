# frozen_string_literal: true

begin
  require "rspec/core"
rescue LoadError
  raise LoadError, 'mo_scenes/rspec requires rspec-core. Add gem "rspec" to your Gemfile.'
end

module MoScenes
  module RSpec
    def self.install!(config)
      config.include MoScenes::RSpecHelper

      config.prepend_before(:each) do
        MoScenes.runner.ensure_global_scenes_loaded!
      end

      config.append_after(:each) do
        MoScenes.registry.clear_per_test_scenes!
      end

      config.after(:suite) do
        MoScenes.runner.rollback_global_transaction!
      end
    end
  end
end
