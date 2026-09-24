class Recording < ActiveRecord::Base
  records :recordable, types: Recordable::TYPES, inverse_of: :recordings

  belongs_to :bucket, optional: true
  belongs_to :creator, class_name: "User", optional: true
  belongs_to :parent, class_name: "Recording", optional: true

  has_many :children, class_name: "Recording", foreign_key: :parent_id, dependent: :destroy
  has_many :events, dependent: :nullify

  delegate :commentable?, :publishable?, :nestable?, :summary, to: :recordable
end
