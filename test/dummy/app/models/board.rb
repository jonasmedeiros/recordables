class Board < ActiveRecord::Base
  recordable
  trashable
  repoint_on_revise :cards

  has_many :cards

  validates :title, presence: true

  def summary = title
end
