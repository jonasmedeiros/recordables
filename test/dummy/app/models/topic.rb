class Topic < ActiveRecord::Base
  recordable
  trashable
  immutable

  validates :title, presence: true

  def summary = title
end
