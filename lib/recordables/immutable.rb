require "active_support/concern"

module Recordables
  # Raised by a write attempted directly against a persisted immutable
  # recordable — see Immutable for why, and what to call instead.
  class ImmutableRecordable < StandardError; end

  # Opt-in alongside `recordable` for a type that should never be updated
  # in place after it's first saved — only revise() (a new row) or trash!
  # (on its Recording) should ever change what a caller sees.
  #
  #   class RoutineTemplate < ApplicationRecord
  #     recordable
  #     immutable
  #   end
  #
  # Nothing in Rails stops a plain `template.update!(name: "x")` from
  # working even after adopting the revise() pattern — it just silently
  # mutates the row in place instead of raising or inserting a new one.
  # The row still looks "current" to every reader, but no new Recording
  # snapshot was created: no history entry, no way to revert, and any
  # cache_version or updated_at logic that reads through the Recording
  # never sees the change. That's exactly the failure this gem exists to
  # prevent, and nothing about #recordable on its own stops it.
  #
  # Only guards persisted rows: the record/revise flow itself calls
  # `.new(...).save!` on a fresh, not-yet-persisted instance, which is
  # the one write path this is not meant to catch.
  module Immutable
    extend ActiveSupport::Concern

    included do
      before_update { raise_immutable!(:update) }
      before_destroy { raise_immutable!(:destroy) }
    end

    # update_column/update_columns/delete bypass callbacks entirely (that's
    # their whole point), so before_update/before_destroy above never see
    # them — each needs its own override to still be caught.
    def update_column(...) = raise_immutable!(:update_column)
    def update_columns(...) = raise_immutable!(:update_columns)
    def delete = raise_immutable!(:delete)

    class_methods do
      def update_all(...)
        raise Recordables::ImmutableRecordable, <<~MESSAGE.squish
          #{name}.update_all writes directly to the row instead of calling
          revise() on each recordable's Recording — no new snapshot, no
          history entry, nothing to revert to. Loop and call
          recording.revise(actor:, **changes) per row instead.
        MESSAGE
      end
    end

    private

      def raise_immutable!(verb)
        raise Recordables::ImmutableRecordable, <<~MESSAGE.squish
          #{self.class.name}##{verb} was called directly on a persisted
          recordable — #{verb == :destroy ? "trash! its Recording" : "call revise(actor:, **changes) on its Recording"}
          instead, so the change goes through the versioning this gem
          exists to provide.
        MESSAGE
      end
  end
end
