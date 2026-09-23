require "active_support/concern"

module Recordables
  # Raised by delete_all/destroy_all on a trashable model — see Trashable
  # for why those are ambiguous under a default_scope that hides trashed
  # rows, and what to call instead.
  class AmbiguousBulkDelete < StandardError; end

  # Opt-in alongside `recordable` for a type whose Recording can be trashed.
  # Without this, a trashed Recording's recordable row stays visible to every
  # plain query — trash! only changes the Recording's own status, nothing
  # about the row a bare Model.find or Model.where sees. This scopes normal
  # queries down to rows with an active Recording, the same way a real DELETE
  # would look to callers that never think about trashing at all.
  #
  #   class RoutineTemplate < ApplicationRecord
  #     recordable
  #     trashable
  #   end
  #
  # Uses a subquery, not a join, so it composes safely everywhere — including
  # inside Recording#recordable itself, which must still resolve a trashed
  # row's own class via a plain Model.find under the hood.
  module Trashable
    extend ActiveSupport::Concern

    included do
      # ::Recording, not Recording — inside this module's lexical scope,
      # plain `Recording` resolves to Recordables::Recording (the concern
      # mixed into the host app's Recording class) rather than the host
      # app's top-level Recording class itself.
      default_scope {
        where(primary_key => ::Recording.active.where(recordable_type: name).select(:recordable_id))
      }
    end

    class_methods do
      # Lifts the trashed-row filter only — unlike .unscoped, every other
      # condition already built on the relation stays intact (an account's
      # scoping association chain, an explicit .find(id), etc). Needed
      # anywhere that has to see trashed rows on purpose: an admin trash-can
      # view, a cascading destroy that has to clean up what it can still see,
      # or a backfill migration creating the very first Recording a row will
      # ever have (see the docs on that gotcha below).
      def with_trashed
        unscope(where: primary_key)
      end

      # A bare Model.delete_all/destroy_all under default_scope only ever
      # touches rows with an active Recording — anything already trashed is
      # invisible to it and survives untouched. That's silent and easy to
      # mistake for "the table's empty now" (a test teardown's delete_all,
      # a DatabaseCleaner truncation strategy, a rake task clearing a
      # table) when it's actually only ever cleared the active subset.
      # Raising forces the caller to say which they mean; scoping down
      # first (e.g. Model.where(...).delete_all) still works exactly like
      # any other ActiveRecord relation.
      def delete_all(...)
        raise Recordables::AmbiguousBulkDelete, <<~MESSAGE.squish
          #{name}.delete_all only deletes rows with an active Recording —
          anything already trashed stays behind, silently. Call
          #{name}.with_trashed.delete_all if that's really what you want,
          or scope down first (e.g. #{name}.where(...).delete_all) if you
          meant only the active rows matching some condition.
        MESSAGE
      end

      def destroy_all(...)
        raise Recordables::AmbiguousBulkDelete, <<~MESSAGE.squish
          #{name}.destroy_all only destroys rows with an active Recording —
          anything already trashed stays behind, silently. Call
          #{name}.with_trashed.destroy_all if that's really what you want,
          or scope down first (e.g. #{name}.where(...).destroy_all) if you
          meant only the active rows matching some condition.
        MESSAGE
      end
    end
  end
end
