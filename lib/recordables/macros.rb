module Recordables
  # Class macros mixed into ActiveRecord::Base, so a model reads the way the
  # rest of Rails does — `records`, not `include SomeModule`.
  module Macros
    # The spine. Wraps delegated_type so one call sets up the pointer, the type
    # scopes, and the snapshot/version API together.
    #
    #   class Recording < ApplicationRecord
    #     records :recordable, types: Recordable::TYPES
    #   end
    def records(role, types:, **options)
      include Recordables::Recording

      delegated_type role, types: types, **options
    end

    # An immutable content type: edits insert a new row instead of updating one.
    #
    #   class Post < ApplicationRecord
    #     recordable
    #   end
    def recordable
      include Recordables::Recordable
    end
  end
end
