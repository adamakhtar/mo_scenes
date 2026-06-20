# MoScenes — Decision Log

## What is MoScenes?

A Rails gem that provides an alternative to YAML fixtures for test data bootstrapping. Instead of YAML files, users define "scenes" — Ruby classes that create ActiveRecord objects and return them as named references. Scenes are loaded once before the test suite inside a transaction, and each test runs inside a savepoint that rolls back after the test, keeping the scene data intact across tests.

---

## Decisions Made

### 1. Scene class design — plain Ruby class with `call`

**Decision:** A scene is a class inheriting from `MoScenes::Scene` with a `call` instance method that returns a hash of `{ symbol => AR record }`.

**Why:** No DSL magic needed. `call` is a well-understood Ruby convention. The returned hash gives us named references with zero metaprogramming in the scene itself. Users write plain ActiveRecord code they already know.

**Example:**
```ruby
class SmallProjectScene < MoScenes::Scene
  def call
    project = Project.create!(name: "Small")
    todo = project.todos.create!(title: "Shopping")
    { project: project, shopping_todo: todo }
  end
end
```

### 2. `_scene` / `Scene` suffix is mandatory

**Decision:** Scene classes must end in `Scene`. The accessor name strips this suffix: `SmallProjectScene` -> `small_project(:record)`.

**Why:** Prevents naming collisions with existing test helper methods (e.g. a scene called `Users` colliding with a `users` helper). The suffix also makes the purpose of the class self-documenting.

### 3. File ordering via numeric prefixes, not `depends_on`

**Decision:** Scene files are loaded in sorted filename order. Users prefix filenames with numbers to control order (e.g. `001_users_scene.rb`, `002_small_project_scene.rb`).

**Alternative considered:** A `depends_on :other_scene` declaration with topological sort. Rejected for v1 because manual ordering is simpler to understand, implement, and debug. The user has full visibility into load order by looking at the filenames.

**Why not Zeitwerk autoloading?** Scene files live in `test/scenes/` (not in `app/`), so they aren't on Rails' autoload paths. We load them ourselves via `Kernel.load` in sorted order. This means numeric prefixes in filenames don't cause any issues — the class name inside the file is what matters, not the filename.

### 4. Cross-scene references via `scene(:name).record`

**Decision:** Scene classes have a `scene` instance method. Calling `scene(:users)` returns a `SceneResult` wrapper with dot-access to that scene's named records. These are the actual in-memory AR objects (no DB round-trip during setup).

**Why:** Scenes are loaded in order inside the same transaction. Scene B can reference scene A's records directly. No need for DB lookups during setup since everything is in-memory in the same transaction.

**Error handling:** If scene B calls `scene(:a)` and scene A hasn't been loaded yet, raises `MoScenes::SceneNotLoadedError` with a message suggesting the user reorder their files.

**Circular dependencies:** Linear ordering cannot resolve true circular dependencies (A needs B, B needs A). This is a user logic error. The `SceneNotLoadedError` makes the problem immediately obvious. In practice, circular scene dependencies indicate a design issue in the test data — three scenes referencing each other linearly (A -> B uses A -> C uses A and B) works fine.

### 5. Test accessors defined via `define_method`, not `method_missing`

**Decision:** After scenes are loaded, accessor methods (e.g. `small_project`) are defined directly on `MoScenes::TestHelper` using `define_method`.

**Alternative considered:** `method_missing` with `respond_to_missing?`. Rejected because:
- Typos produce clearer `NoMethodError` messages with defined methods
- Slightly better IDE support
- No performance concern either way for ~20 scenes, but defined methods are zero-overhead dispatch

### 6. Per-test caching of record lookups

**Decision:** Each call to a scene accessor (e.g. `small_project(:project)`) caches the result in `@scene_cache`, a test instance variable. First call does `Model.find(pk)`, subsequent calls in the same test return the cached object. Pass `reload: true` to force a fresh DB read.

**Why:** Avoids redundant DB hits when the same record is accessed multiple times in a test. The cache is naturally scoped to the test instance — no manual cleanup needed between tests.

**Follows Rails fixtures pattern:** Rails fixtures cache records per-test in `@fixture_cache` with the same semantics.

### 7. Transaction management — outer transaction + Rails savepoints

**Decision:** Piggyback on Rails' `use_transactional_tests`:
1. Before the first test, open an outer transaction and load all global scenes
2. Rails' `use_transactional_tests` creates a savepoint per-test within our outer transaction
3. After each test, Rails rolls back the savepoint (scene data persists)
4. After the suite, roll back the outer transaction (DB returns to clean state)

**Why:** This mirrors exactly how Rails fixtures work. The outer transaction ensures scene data is never committed to the DB, and savepoints give per-test isolation.

**Hook timing:** Our `before_setup` runs before Rails' via `prepend`, so the outer transaction is opened before Rails creates its per-test savepoint.

### 8. Fresh records in tests via `Model.find(pk)`

**Decision:** Test accessors always return a fresh record from the DB (via `find`), not the in-memory object from when the scene was loaded.

**Why:** A test might mutate an object in memory (e.g. `project.name = "changed"` without saving). If the next test received the same in-memory object, it would see stale data. `find` guarantees each test gets a clean object reflecting the DB state (which is the original scene data, since the savepoint rolled back any changes).

### 9. Global vs per-test scenes

**Decision:** Scenes are global by default (`self.global = true`). Set `self.global = false` for scenes only loaded on demand via `load_scene(:name)` in individual tests.

**Per-test scene lifecycle:** `load_scene` runs the scene's `call` inside the current test's savepoint. When the test ends and the savepoint rolls back, the data is gone. `Registry.clear_per_test_scenes!` in `after_teardown` removes the stale PK entries so the next test doesn't try to `find` records that were rolled back.

**Same accessor pattern:** Both global and per-test scenes use the same `scene_name(:record)` accessor. Per-test scenes get their method defined via `define_method` when `load_scene` is called.

### 10. Seeds API

**Decision:** Three methods for use in `db/seeds.rb`:
- `MoScenes.load_all` — runs all global scenes
- `MoScenes.load_only(:users, :projects)` — runs specific scenes
- `MoScenes.load_without(:large_project)` — runs all except named scenes

**Why:** Scenes as seeds avoids duplicating data setup logic. No transaction wrapping — records are committed. The three methods give enough flexibility without overcomplicating the API.

### 11. Helpful error messages

**Decision:** `Registry.fetch` raises `MoScenes::RecordNotFoundError` when an invalid record name is passed, listing available record names. Example: `Scene :small_project has no record :projecct. Available records: :project, :shopping_todo`.

**Why:** Typos in record names are common. A helpful error message with available names saves debugging time.

### 12. Database cleanliness follows Rails fixtures pattern

**Decision:** Before loading scenes, truncate affected tables. Outer transaction rollback handles normal cleanup. `Minitest.after_run` + `at_exit` as a safety net for crashes.

**Why:** Matches the proven Rails fixtures approach. If a test run crashes before the outer transaction rolls back, the safety net ensures the DB is cleaned up.

### 13. Parallel test support

**Decision:** Supported. Each parallel worker (forked process) has its own database, its own outer transaction, and its own process-local Registry state.

**Why:** Works naturally because `ensure_global_scenes_loaded!` is idempotent per-process, and class-level instance variables on Registry are per-process after fork. No special handling needed.

### 14. Test framework support — Minitest and RSpec

**Decision:** Framework-specific code lives in `lib/mo_scenes/minitest/` and `lib/mo_scenes/rspec/`. Shared example API is in `MoScenes::ExampleGroupHelper`; dynamic accessors are defined there by Runner.

**Minitest:** Opt-in via `require "mo_scenes/minitest"`. `MoScenes::TestHelper` prepends lifecycle hooks on `before_setup` / `after_teardown`. `Minitest.after_run` rolls back the outer transaction.

**RSpec:** Opt-in via `require "mo_scenes/rspec"` and `MoScenes::RSpec.install!(RSpec.configuration)`. Uses `prepend_before(:each)`, `append_after(:each)`, and `after(:suite)` for the same lifecycle.

**Scenes path:** Resolved lazily in `Configuration#scenes_path` — `spec/scenes` when `defined?(RSpec)` at test run time, otherwise `test/scenes`. Explicit `MoScenes.configure` override always wins.

---

## Decisions Deferred

### Multiple database support

**Status:** Punted for v1.

**Context:** Rails 6+ supports multiple databases. Scenes might need to know which DB connection a record belongs to. For v1, we assume a single database. Multi-DB support could be added later by allowing scenes to declare their connection or by iterating over all active connections.

### `depends_on` DSL for scene ordering

**Status:** Not included in v1. May revisit if manual ordering proves painful.

**Context:** A `depends_on :other_scene` declaration would allow automatic topological sorting of scene load order. Rejected for now because numeric file prefixes are simpler and more transparent. If users frequently struggle with ordering (especially in large projects with many scenes), this could be added as opt-in sugar on top of the existing system.

### RSpec support

**Status:** Implemented.

**Context:** `MoScenes::RSpec.install!` registers RSpec hooks mirroring Minitest lifecycle. Shared accessors via `ExampleGroupHelper`.

### Deterministic IDs (hash-based like fixtures)

**Status:** Not implementing.

**Context:** Rails fixtures assign deterministic IDs based on a hash of the fixture label name. MoScenes uses `create!` which gives auto-increment IDs. These are stable as long as scene order and the number of `create!` calls within each scene remain the same. Since records are always accessed by name (`small_project(:project)`) rather than by ID, non-deterministic IDs are not a practical issue. If someone hardcodes an ID in a test assertion, that's a code smell regardless.

### Rake task `db:scenes:load`

**Status:** Planned but low priority.

**Context:** Equivalent to `db:fixtures:load`. Would load scenes outside a transaction and commit to the DB. Useful for populating a development database without going through `db/seeds.rb`. Implementation is trivial once the core is built.
