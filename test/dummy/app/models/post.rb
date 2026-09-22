class Post < ActiveRecord::Base
  recordable

  validates :title, presence: true

  def commentable? = true

  def summary = title
end
