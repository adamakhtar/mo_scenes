# frozen_string_literal: true

class LargeProjectScene < MoScenes::Scene
  self.global = false

  def call
    owner = scene(:users).admin
    project = Project.create!(name: "Large Project", user: owner)
    todos = 15.times.map do |i|
      project.todos.create!(title: "Task #{i + 1}")
    end
    { project: project, first_todo: todos.first }
  end
end
