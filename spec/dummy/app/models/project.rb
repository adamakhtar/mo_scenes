# frozen_string_literal: true

class Project < ActiveRecord::Base
  belongs_to :user
  has_many :todos
end
