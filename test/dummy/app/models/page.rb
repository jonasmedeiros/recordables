class Page < ActiveRecord::Base
  recordable

  has_rich_text :content
  has_one_attached :cover

  validates :title, presence: true

  def commentable? = true

  def summary = title
end
