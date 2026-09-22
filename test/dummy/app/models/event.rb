class Event < ActiveRecord::Base
  belongs_to :recording
  belongs_to :recordable, polymorphic: true
  belongs_to :actor, class_name: "User"

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
end
