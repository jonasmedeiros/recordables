class Playlist < ActiveRecord::Base
  recordable
  has_children :tracks
  nested_recordable_attributes_for :tracks

  validates :title, presence: true

  def summary = title
end
