require "active_support/concern"

module Recordables
  module Recording
    extend ActiveSupport::Concern

    VERSION_ACTIONS = %w[created updated reverted].freeze

    included do
      # The install generator's migration creates the status column
      # (integer, default 0, not null) but doesn't declare the enum itself
      # — active/trash! need this exact mapping to exist, so it lives here
      # rather than being left for every consumer to redeclare correctly.
      enum :status, { active: 0, archived: 1, trashed: 2 }
    end

    class_methods do
      def record(recordable, actor:, parent: nil, **attributes)
        transaction do
          recordable.save!
          recording = create!(recordable: recordable, creator: actor, parent: parent, **attributes)
          recording.log!("created", recordable, actor: actor)
          recording
        end
      end

      # Every other scope on this table should build on this one rather than
      # querying status directly — trashable's default_scope depends on
      # filtering through exactly this relation so a model swap here (e.g.
      # adding a soft-delete concern upstream) only has one place to change.
      def active = where(status: :active)
    end

    def revise(actor:, **changes)
      transaction do
        revision = recordable.class.new(recordable.revisable_attributes)
        recordable.copy_content_to(revision)
        changes.each { |name, value| revision.public_send(:"#{name}=", value) }
        revision.save!
        update!(recordable: revision)
        log!("updated", revision, actor: actor, details: { "changed" => changes.keys.map(&:to_s) })
        revision
      end
    end

    def revert_to(snapshot, actor:)
      transaction do
        update!(recordable: snapshot)
        log!("reverted", snapshot, actor: actor, details: { "restored_id" => snapshot.id })
        snapshot
      end
    end

    def versions = events.where(action: VERSION_ACTIONS).order(:created_at, :id)

    def recordable_at(time) = versions.where(created_at: ..time).last&.recordable

    def log!(action, snapshot, actor:, details: {})
      events.create!(recordable: snapshot, actor: actor, action: action, details: details)
    end

    # "Deleting" a recordable never removes a row — it marks this pointer
    # trashed and logs the transition, the same way revise/revert_to never
    # delete either. A trashed Recording keeps recordable/versions/events
    # working exactly as before; only .active-scoped lookups stop seeing it.
    def trash!(actor: nil)
      transaction do
        update!(status: :trashed)
        log!("trashed", recordable, actor: actor)
      end
    end
  end
end
