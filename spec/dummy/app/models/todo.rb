# frozen_string_literal: true

class Todo < ActiveRecord::Base
  belongs_to :project
end
