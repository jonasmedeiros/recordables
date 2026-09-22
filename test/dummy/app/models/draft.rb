class Draft < ActiveRecord::Base
  recordable

  has_many :tags

  validates :title, presence: true

  def summary = title
end
