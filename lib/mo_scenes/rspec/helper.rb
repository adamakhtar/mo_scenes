# frozen_string_literal: true

require_relative "../example_group_helper"

module MoScenes
  module RSpec
    module Helper
      include ExampleGroupHelper
    end
  end

  RSpecHelper = RSpec::Helper
end
