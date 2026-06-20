# MoScenes

Scene-based test data bootstrapping for Rails. An alternative to YAML fixtures.

Define test data as Ruby classes ("scenes") that create ActiveRecord records once before the test suite, wrapped in a transaction for fast per-test rollback. No YAML, no factories-per-test, no slow inserts.

## How It Works

1. You define scene classes that create records and return named references
2. All global scenes are loaded once before the test suite inside a database transaction
3. Each test runs inside a savepoint — modifications roll back automatically
4. Accessors like `small_project(:project)` load records from the DB (cached within each test)
5. Scenes can also be used as seed data for development

## Installation

Add to your Gemfile:

```ruby
gem "mo_scenes"
```

## AI Coding Assistants

MoScenes includes an assistant-friendly skill document for LLMs that are helping you create or edit scenes.

Generate it into your Rails app:

```bash
bin/rails generate mo_scenes:ai_skill
```

By default this writes `docs/ai/mo-scenes-skill.md`. You can also use a named assistant target:

```bash
bin/rails generate mo_scenes:ai_skill claude
bin/rails generate mo_scenes:ai_skill cursor
```

The `claude` target writes `.claude/skills/mo-scenes/SKILL.md`. The `cursor` target writes `.cursor/rules/mo_scenes.mdc`. You can also pass a custom destination path.

## Setup

### 1. Create a scenes directory

Minitest apps:

```
test/
  scenes/
    001_users_scene.rb
    002_small_project_scene.rb
    003_large_project_scene.rb
```

RSpec apps:

```
spec/
  scenes/
    001_users_scene.rb
    002_small_project_scene.rb
    003_large_project_scene.rb
```

Files are loaded in sorted order. Scene files must be named `*_scene.rb`. Use numeric prefixes to control load order.

The default scenes path is `test/scenes`, or `spec/scenes` when RSpec is loaded at test time. RSpec-only apps should configure the path explicitly — seeds and rake tasks run outside the test suite and default to `test/scenes`:

```ruby
MoScenes.configure do |config|
  config.scenes_path = Rails.root.join("spec", "scenes").to_s
end
```

### 2. Include the test helper

**Minitest** — in `test/test_helper.rb`:

```ruby
require "mo_scenes/minitest"

class ActiveSupport::TestCase
  include MoScenes::TestHelper
end
```

**RSpec** — in `spec/rails_helper.rb`:

```ruby
require "mo_scenes/rspec"

MoScenes::RSpec.install!(RSpec.configuration)
```

If you're not using the Railtie (e.g. outside Rails), configure the scenes path:

```ruby
MoScenes.configure do |config|
  config.scenes_path = File.join(__dir__, "scenes")
end
```

## Defining Scenes

A scene is a class that inherits from `MoScenes::Scene` and implements `call`. The class name **must** end with `Scene`.

```ruby
# test/scenes/001_users_scene.rb
class UsersScene < MoScenes::Scene
  def call
    admin = User.create!(name: "Admin", role: "admin")
    member = User.create!(name: "Member", role: "member")
    { admin: admin, member: member }
  end
end
```

`call` returns a hash mapping names (symbols) to ActiveRecord objects. These names become the keys you use to access records in tests.

### Cross-scene references

Later scenes can reference records from earlier scenes using the `scene` helper:

```ruby
# test/scenes/002_small_project_scene.rb
class SmallProjectScene < MoScenes::Scene
  def call
    owner = scene(:users).admin
    project = Project.create!(name: "Small Project", user: owner)
    todo = project.todos.create!(title: "Shopping")
    { project: project, shopping_todo: todo }
  end
end
```

`scene(:users)` returns an object with dot-access to all records from `UsersScene`. If the referenced scene hasn't been loaded yet, you'll get a `MoScenes::SceneNotLoadedError` telling you to reorder your files.

## Using Scenes in Tests

**Minitest:**

```ruby
class ProjectTest < ActiveSupport::TestCase
  test "project belongs to admin" do
    project = small_project(:project)
    admin = users(:admin)
    assert_equal admin.id, project.user_id
  end

  test "fetch multiple records" do
    project, todo = small_project(:project, :shopping_todo)
    assert_equal project, todo.project
  end
end
```

**RSpec:**

```ruby
RSpec.describe Project do
  it "belongs to admin" do
    project = small_project(:project)
    admin = users(:admin)
    expect(project.user_id).to eq(admin.id)
  end

  it "fetches multiple records" do
    project, todo = small_project(:project, :shopping_todo)
    expect(todo.project).to eq(project)
  end
end
```

### Caching

The first call to `small_project(:project)` in a test does a `Model.find(pk)` and caches the result. Subsequent calls in the same test return the cached object. The cache is automatically cleared between tests.

To force a fresh DB read:

```ruby
project = small_project(:project, reload: true)
```

### Per-test scenes

Mark a scene as non-global to load it only in specific tests:

```ruby
class LargeProjectScene < MoScenes::Scene
  self.global = false

  def call
    owner = scene(:users).admin
    project = Project.create!(name: "Large Project", user: owner)
    15.times { |i| project.todos.create!(title: "Task #{i + 1}") }
    { project: project }
  end
end
```

Load it explicitly in a test:

```ruby
# Minitest
test "large project has many todos" do
  load_scene(:large_project)
  project = large_project(:project)
  assert_equal 15, project.todos.count
end

# RSpec
it "has many todos" do
  load_scene(:large_project)
  project = large_project(:project)
  expect(project.todos.count).to eq(15)
end
```

Per-test scene data is created inside the test's savepoint and rolled back when the test ends.

## Error Messages

Invalid record names produce helpful errors:

```
MoScenes::RecordNotFoundError: Scene :small_project has no record :projecct.
  Available records: :project, :shopping_todo
```

## Using Scenes as Seeds

Scenes can double as seed data for development:

```ruby
# db/seeds.rb
require "mo_scenes"

MoScenes.load_all                        # all global scenes
MoScenes.load_only(:users, :small_project)  # specific scenes
MoScenes.load_without(:large_project)    # all except some
```

When used as seeds, records are committed (no transaction wrapping).

You can also use the rake task:

```
bin/rails db:scenes:load
```

## Transaction Lifecycle

```
Before suite:  Open outer transaction -> Load all global scenes
Per test:      Rails savepoint -> Test runs -> Rollback savepoint
After suite:   Rollback outer transaction (DB returns to clean state)
```

Requires transactional tests (`use_transactional_tests = true` for Minitest; `use_transactional_tests` or `use_transactional_fixtures` for RSpec via rspec-rails).

## Configuration

| Option | Default | Description |
|---|---|---|
| `scenes_path` | `test/scenes` or `spec/scenes` (lazy, based on whether RSpec is loaded) | Directory containing scene files |

## Requirements

- Ruby >= 3.0
- Rails >= 7.0 (ActiveRecord + ActiveSupport)
- Minitest or RSpec (with rspec-rails)
- Transactional tests enabled (see Transaction Lifecycle above)

## License

MIT
