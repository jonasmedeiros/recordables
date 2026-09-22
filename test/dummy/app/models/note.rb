class Note < ActiveRecord::Base
  recordable

  validates :body, presence: true

  def summary = body
end
