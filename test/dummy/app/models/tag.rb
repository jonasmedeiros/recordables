class Tag < ActiveRecord::Base
  belongs_to :draft, optional: true
  recordable_belongs_to :topic, optional: true
end
