class Track < ActiveRecord::Base
  recordable

  validates :title, presence: true

  def summary = title
end
