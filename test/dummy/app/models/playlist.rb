class Playlist < ActiveRecord::Base
  recordable
  has_children :tracks
  nested_recordable_attributes_for :tracks,
    recording_attributes: ->(playlist) { { position: playlist.tracks.count + 100 } }

  validates :title, presence: true

  def summary = title
end
