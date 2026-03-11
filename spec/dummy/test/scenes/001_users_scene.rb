# frozen_string_literal: true

class UsersScene < MoScenes::Scene
  def call
    admin = User.create!(name: "Admin", role: "admin")
    member = User.create!(name: "Member", role: "member")
    { admin: admin, member: member }
  end
end
