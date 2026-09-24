class Event < ActiveRecord::Base
  belongs_to :recording, optional: true
  belongs_to :recordable, polymorphic: true
  belongs_to :actor, class_name: "User", optional: true

  before_create { self.actor_name ||= actor&.name }

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def actor_label = actor&.name || actor_name
end
