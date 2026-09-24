class Topic < ActiveRecord::Base
  recordable
  immutable

  validates :title, presence: true

  def summary = title
end
