---
name: mo-scenes
description: Use MoScenes in Rails test suites. Apply when creating, editing, or reviewing MoScenes scene files, replacing fixtures or factories, setting up scene-based test data, writing Minitest or RSpec tests that consume scenes, or debugging MoScenes scene loading and accessor errors.
---

# MoScenes

MoScenes is a Rails gem for scene-based test data bootstrapping. Use it when a Rails app wants reusable test data defined as Ruby classes instead of YAML fixtures or per-test factories.

## Testing Philosophy

MoScenes favors creating stable, shared baseline data once before the test suite instead of inserting equivalent records in every test case.

Per-test factories and setup blocks are fine for truly test-specific data, but repeated inserts add up across large Rails suites. Prefer global scenes for common domain records that many tests read or lightly mutate. Each test runs inside a transaction/savepoint, so mutations roll back and the global scene data remains available for the next test.

Use non-global scenes for expensive or narrow scenarios that only a few tests need.

## Core Model

A scene is a Ruby class that inherits from `MoScenes::Scene` and implements `call`.

Scene files usually live in:

```text
test/scenes/   # Minitest apps
spec/scenes/   # RSpec apps
```

The default path is resolved lazily at test run time: `spec/scenes` when RSpec is loaded, otherwise `test/scenes`.

Files are loaded in sorted filename order. Prefer numeric prefixes when scenes depend on earlier scenes:

```text
test/scenes/   # or spec/scenes/
  001_users_scene.rb
  002_small_project_scene.rb
```

Scene class names must end with `Scene`.

## Defining Scenes

Use this pattern:

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

`call` must return a hash whose keys are symbolic record names and whose values are ActiveRecord objects.

Prefer stable domain names over incidental implementation details:

```ruby
{ admin: admin, project: project, shopping_todo: todo }
```

## Referencing Other Scenes

Later scenes can reference earlier scenes with `scene(:name)`.

```ruby
class SmallProjectScene < MoScenes::Scene
  def call
    owner = scene(:users).admin

    project = Project.create!(name: "Small Project", user: owner)
    todo = project.todos.create!(title: "Shopping")

    { project: project, shopping_todo: todo }
  end
end
```

If a scene depends on another scene, ensure the dependency file sorts earlier. Do not create circular scene dependencies.

## Using Scenes In Tests

Scene names become helper methods. Record names are passed as symbols.

**Minitest:**

```ruby
class ProjectTest < ActiveSupport::TestCase
  test "project belongs to admin" do
    project = small_project(:project)
    admin = users(:admin)

    assert_equal admin.id, project.user_id
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
end
```

Multiple records can be fetched at once:

```ruby
project, todo = small_project(:project, :shopping_todo)
```

Use `reload: true` when a test needs a fresh database read:

```ruby
project = small_project(:project, reload: true)
```

## Per-Test Scenes

Global scenes load once before the suite. For expensive or scenario-specific data, mark the scene non-global:

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

Load non-global scenes explicitly inside tests:

```ruby
load_scene(:large_project)
project = large_project(:project)
```

Per-test scene data is created inside the test transaction/savepoint and rolls back after the test.

## Setup

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

MoScenes expects Rails transactional tests:

```ruby
# Minitest
self.use_transactional_tests = true

# RSpec (rspec-rails 6+)
config.use_transactional_tests = true
```

If not using the Railtie, configure the scenes path explicitly:

```ruby
MoScenes.configure do |config|
  config.scenes_path = File.join(__dir__, "scenes")
end
```

## Seeds

Scenes can be reused as development seed data:

```ruby
# db/seeds.rb
require "mo_scenes/seed_helper"

MoScenes.load_all
MoScenes.load_only(:users, :small_project)
MoScenes.load_without(:large_project)
```

Or use:

```bash
bin/rails db:scenes:load
```

## Agent Workflow

When asked to create or edit MoScenes scenes:

1. Detect whether the app uses Minitest or RSpec, then choose the correct setup and scenes directory (`test/scenes` vs `spec/scenes`).
2. Inspect existing scene files and preserve naming/order conventions.
3. Inspect relevant ActiveRecord models, validations, required associations, and database constraints.
4. Prefer existing global scene records over creating duplicate per-test data.
5. Put shared baseline records in global scenes.
6. Put expensive or narrow scenario data in `self.global = false` scenes.
7. Return every record that tests should access from `call`.
8. Use `scene(:dependency).record_name` instead of duplicating records across scenes.
9. Update or add tests to consume scenes through helper accessors.
10. Run the relevant Rails tests if available.

## Avoid

Do not use YAML fixture syntax inside scenes.

Do not use factories inside scenes unless the app already has a deliberate local convention for doing so.

Do not rely on implicit file ordering when scenes depend on each other; use filename prefixes.

Do not return plain hashes, IDs, or non-ActiveRecord values as scene records unless the project has explicitly chosen that convention.

Do not create records in tests when they belong in reusable baseline scene data.

Do not mark large scenario-specific scenes as global unless many tests need them.

## Debugging

If an accessor is missing, check that:

- Minitest: `MoScenes::TestHelper` is included in `ActiveSupport::TestCase`
- RSpec: `MoScenes::RSpec.install!(RSpec.configuration)` is called in `rails_helper.rb`
- the scene class name ends with `Scene`
- the scene file is under the configured scenes path (`test/scenes` or `spec/scenes`)
- the scene file loaded before dependent scenes
- the accessor name matches the scene name, e.g. `SmallProjectScene` -> `small_project`

If a record name is missing, check that `call` returns that key:

```ruby
{ project: project }
```

Then access it as:

```ruby
small_project(:project)
```
