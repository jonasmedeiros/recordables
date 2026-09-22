class Project < ActiveRecord::Base
  include Bucketable

  validates :name, presence: true
end
