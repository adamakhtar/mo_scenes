# frozen_string_literal: true

require "mo_scenes/rspec"

RSpec.describe MoScenes::RSpec do
  FakeConfig = Struct.new(:included_modules, :before_suite_hooks, :append_after_hooks, :after_suite_hooks, keyword_init: true) do
    def include(mod)
      included_modules << mod
    end

    def before(*args, &block)
      before_suite_hooks << { args: args, block: block }
    end

    def append_after(*args, &block)
      append_after_hooks << { args: args, block: block }
    end

    def after(*args, &block)
      after_suite_hooks << { args: args, block: block }
    end
  end

  before { MoScenes.reset! }
  after { MoScenes.reset! }

  def build_config
    FakeConfig.new(
      included_modules: [],
      before_suite_hooks: [],
      append_after_hooks: [],
      after_suite_hooks: []
    )
  end

  it "includes RSpecHelper" do
    config = build_config

    described_class.install!(config)

    expect(config.included_modules).to include(MoScenes::RSpecHelper)
  end

  it "registers lifecycle hooks" do
    config = build_config

    described_class.install!(config)

    expect(config.before_suite_hooks.first[:args]).to eq([:suite])
    expect(config.append_after_hooks.first[:args]).to eq([:each])
    expect(config.after_suite_hooks.first[:args]).to eq([:suite])
  end

  it "loads global scenes in before suite hook" do
    config = build_config
    described_class.install!(config)

    called = false
    MoScenes.runner.define_singleton_method(:ensure_global_scenes_loaded!) do
      called = true
    end

    config.before_suite_hooks.first[:block].call
    expect(called).to be true
  end

  it "clears per-test scenes in append_after hook" do
    config = build_config
    described_class.install!(config)

    called = false
    MoScenes.registry.define_singleton_method(:clear_per_test_scenes!) do
      called = true
    end

    config.append_after_hooks.first[:block].call
    expect(called).to be true
  end

  it "rolls back global transaction in after suite hook" do
    config = build_config
    described_class.install!(config)

    called = false
    MoScenes.runner.define_singleton_method(:rollback_global_transaction!) do
      called = true
    end

    config.after_suite_hooks.first[:block].call
    expect(called).to be true
  end
end
