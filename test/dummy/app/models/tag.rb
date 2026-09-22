class Tag < ActiveRecord::Base
  belongs_to :draft, optional: true
end
