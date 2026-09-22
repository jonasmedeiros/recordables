class Bucket < ActiveRecord::Base
  delegated_type :bucketable, types: Bucketable::TYPES, inverse_of: :bucket

  has_many :recordings
  has_many :events, through: :recordings

  def self.open(bucketable)
    bucketable.save! if bucketable.new_record?
    find_or_create_by!(bucketable: bucketable)
  end
end
