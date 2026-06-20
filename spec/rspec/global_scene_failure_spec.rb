# frozen_string_literal: true

require "active_record"
require "mo_scenes/rspec"

require_relative "../dummy/config/application"
require_relative "../dummy/app/models/user"
require_relative "../dummy/app/models/project"
require_relative "../dummy/app/models/todo"

RSpec.describe "MoScenes RSpec global scene failure" do
  HookConfig = Struct.new(:prepend_before_hooks, keyword_init: true) do
    def include(_mod); end

    def prepend_before(*args, &block)
      prepend_before_hooks << { args: args, block: block }
    end

    def append_after(*); end
    def after(*); end
  end

  before do
    MoScenes.reset!
    MoScenes.configure { |c| c.scenes_path = File.join(__dir__, "..", "dummy", "test", "scenes") }
  end

  after { MoScenes.reset! }

  it "does not retry global load across prepend_before hooks" do
    config = HookConfig.new(prepend_before_hooks: [])
    MoScenes::RSpec.install!(config)

    run_count = 0
    MoScenes.runner.define_singleton_method(:run_global_scenes!) do
      run_count += 1
      raise StandardError, "boom"
    end

    hook = config.prepend_before_hooks.first[:block]

    expect { hook.call }.to raise_error(StandardError, "boom")
    expect { hook.call }.to raise_error(StandardError, "boom")
    expect(run_count).to eq(1)
    expect(MoScenes.runner.global_load_failed?).to be true
  end
end
