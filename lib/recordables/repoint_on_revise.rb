require "active_support/concern"

module Recordables
  # Opt-in alongside `recordable` for a type that owns real has_many
  # associations pointed at it by a plain foreign key (not a child
  # Recording) — join rows that need to follow a revision, not vanish
  # when the row they FK to gets replaced.
  #
  #   class RoutineTemplate < ApplicationRecord
  #     recordable
  #     repoint_on_revise :routine_template_people, :goal_routine_templates
  #   end
  #
  # Two problems, one macro:
  #
  # 1. #copy_content_to's default UncopyableAssociation guard exists to
  #    stop a real association from silently vanishing off a new snapshot
  #    — but these associations were never content to copy in the first
  #    place, they're FK pointers *at* the row. Nothing to carry forward;
  #    they need to be repointed instead. This overrides copy_content_to
  #    to a no-op, same as hand-rolling `def copy_content_to(r) = r` would.
  #
  # 2. revise() alone leaves every one of those rows FK'd to the OLD,
  #    now-superseded id — invisible to anything that reads the
  #    association off the new row, and (worse) silently orphaned if that
  #    old row is later trashed or garbage collected. This overrides
  #    revise() to repoint each named association's foreign key at the new
  #    row in the same transaction as the revision itself.
  #
  # update_all skips touch callbacks, so updated_at is bumped by hand —
  # otherwise any fragment cache keyed on those rows (e.g. one that reads
  # `join_row.routine_template.name`) would invalidate late.
  module RepointOnRevise
    extend ActiveSupport::Concern

    included do
      class_attribute :repointed_association_names, default: []
    end

    def copy_content_to(revision) = revision

    def revise(actor: nil, **changes)
      transaction do
        new_row = recording.revise(actor: actor, **changes)

        self.class.repointed_association_names.each do |association_name|
          reflection = self.class.reflect_on_association(association_name)
          foreign_key = reflection.foreign_key

          public_send(association_name).update_all(foreign_key => new_row.id, :updated_at => Time.current)
        end

        new_row
      end
    end
  end
end
