# frozen_string_literal: true

# MoScenes bootstraps test fixture data from Ruby scene classes instead of YAML.
#
# == Architecture overview
#
# Scenes are classes that inherit MoScenes::Scene, implement #call, and return
# a Hash of { record_name => ActiveRecord model }. The gem wires them into tests
# via MoScenes::TestHelper and exposes fixture-style accessors (e.g. users(:admin)).
#
# There are two scene lifecycles:
#
# *Global scenes* (the default — every Scene subclass starts as global):
#   1. Before the first test, Runner loads scene files, opens an outer DB
#      transaction (joinable: false), and runs every global scene's #call.
#   2. Registry stores each scene's result and a PK map (class + primary key
#      per record). Accessors lazy-load via Model.find(pk) so each test sees
#      DB state after savepoint rollback, not stale in-memory objects.
#   3. Rails' transactional tests wrap each example in a savepoint; mutations
#      roll back per test. After the suite, Runner rolls back the outer
#      transaction, removing all scene inserts from the database.
#
# == Why the outer transaction?
#
# Global scenes INSERT once for the whole suite — we do not re-run them per
# test (that would be as slow as factories). When the suite finishes, those
# rows must be gone. The outer transaction achieves that with a single
# rollback instead of committing inserts and cleaning up later (truncate,
# delete_all, database_cleaner, etc.).
#
# The outer transaction holds all global scene inserts uncommitted for the
# suite's lifetime. Rails' per-test savepoints sit inside it: each example can
# mutate scene data and roll back cleanly, while the base rows remain available
# to every subsequent test. One rollback at teardown drops every insert.
#
# joinable: false marks this as MoScenes' own transaction. Without it, Rails'
# per-test transactional wrapper would join the same transaction instead of
# opening a savepoint — and rolling back after each test could undo the global
# scene inserts, not just that example's changes.
#
# *Per-test scenes* (opt out with `self.global = false`, load via load_scene):
#   1. #call runs inside the current test's savepoint when load_scene is invoked.
#   2. Registry marks the scene as per-test; after_teardown clears only those
#      entries so the next example can load fresh data (or skip loading entirely).
#   3. DB rows still roll back via the savepoint — clearing registry state
#      prevents stale PK maps and accessor methods from leaking between tests.
#
# Seed loading (MoScenes.load_all etc.) reuses Registry and scene files but
# commits records normally — no outer transaction.
#
require_relative "mo_scenes/version"
require_relative "mo_scenes/errors"
require_relative "mo_scenes/configuration"
require_relative "mo_scenes/scene_result"
require_relative "mo_scenes/registry"
require_relative "mo_scenes/scene"
require_relative "mo_scenes/runner"
require_relative "mo_scenes/test_helper"
require_relative "mo_scenes/seed_helper"

module MoScenes
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def registry
      @registry ||= Registry.new
    end

    def runner
      @runner ||= Runner.new(registry: registry, configuration: configuration)
    end

    # Tear down gem singletons and roll back the outer transaction. Used by tests
    # and after the suite to leave the database clean.
    def reset!
      @runner&.rollback_global_transaction!
      @configuration = nil
      @registry = nil
      @runner = nil
      @seed_runner = nil
    end
  end
end

require_relative "mo_scenes/railtie" if defined?(Rails::Railtie)
