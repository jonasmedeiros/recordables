class Card < ActiveRecord::Base
  belongs_to :board, optional: true
end
