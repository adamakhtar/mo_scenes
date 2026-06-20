# frozen_string_literal: true

require "active_record"
require "mo_scenes/rspec"
require "open3"

require_relative "../dummy/config/application"
require_relative "../dummy/app/models/user"
require_relative "../dummy/app/models/project"
require_relative "../dummy/app/models/todo"

RSpec.describe "MoScenes RSpec global scene failure" do
  HookConfig = Struct.new(:before_suite_hooks, keyword_init: true) do
    def include(_mod); end

    def before(*args, &block)
      before_suite_hooks << { args: args, block: block }
    end

    def append_after(*); end
    def after(*); end
  end

  before do
    MoScenes.reset!
    MoScenes.configure { |c| c.scenes_path = File.join(__dir__, "..", "dummy", "test", "scenes") }
  end

  after { MoScenes.reset! }

  it "does not retry global load when before suite hook is invoked again" do
    config = HookConfig.new(before_suite_hooks: [])
    MoScenes::RSpec.install!(config)

    run_count = 0
    MoScenes.runner.define_singleton_method(:run_global_scenes!) do
      run_count += 1
      raise StandardError, "boom"
    end

    hook = config.before_suite_hooks.first[:block]

    expect { hook.call }.to raise_error(StandardError, "boom")
    expect { MoScenes.runner.ensure_global_scenes_loaded! }.to raise_error(StandardError, "boom")
    expect(run_count).to eq(1)
    expect(MoScenes.runner.global_load_failed?).to be true
  end

  it "aborts the suite before any examples run" do
    fixture = File.expand_path("support/suite_abort_fixture.rb", __dir__)
    output, status = Open3.capture2e("bundle", "exec", "rspec", fixture, "--format", "documentation")

    expect(status.success?).to be false
    expect(output).to include("boom")
    expect(output).to include("0 examples")
    expect(output).not_to include("this example must not run")
  end
end
