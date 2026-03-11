# frozen_string_literal: true

require "active_record"

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name, null: false
    t.string :role, default: "member"
    t.timestamps
  end

  create_table :projects, force: true do |t|
    t.string :name, null: false
    t.integer :user_id, null: false
    t.timestamps
  end

  create_table :todos, force: true do |t|
    t.string :title, null: false
    t.boolean :completed, default: false
    t.integer :project_id, null: false
    t.timestamps
  end
end
