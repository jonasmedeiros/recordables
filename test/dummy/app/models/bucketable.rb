module Bucketable
  extend ActiveSupport::Concern

  TYPES = %w[Project].freeze

  included do
    has_one :bucket, as: :bucketable, dependent: :destroy
  end

  def bucket! = Bucket.open(self)
end
