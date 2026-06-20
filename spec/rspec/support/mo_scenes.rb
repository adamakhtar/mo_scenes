# frozen_string_literal: true

module MoScenesRSpecSupport
  class << self
    def install!(config)
      return if @installed

      MoScenes::RSpec.install!(config)
      @installed = true
    end
  end
end
