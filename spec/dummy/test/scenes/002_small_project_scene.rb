# frozen_string_literal: true

class SmallProjectScene < MoScenes::Scene
  def call
    owner = scene(:users).admin
    project = Project.create!(name: "Small Project", user: owner)
    shopping_todo = project.todos.create!(title: "Shopping")
    { project: project, shopping_todo: shopping_todo }
  end
end
