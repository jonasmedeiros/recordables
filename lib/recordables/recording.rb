require "active_support/concern"

module Recordables
  module Recording
    extend ActiveSupport::Concern

    VERSION_ACTIONS = %w[created updated reverted].freeze

    # Set only around #destroy!'s own recordable.destroy! call below, so
    # Immutable's before_destroy guard can tell "the gem's own sanctioned
    # destroy path" apart from a caller destroying a recordable directly —
    # the same distinction record/revise draw by only ever calling
    # .new(...).save! and never touching an existing row's update!. Module
    # level (not per-host-Recording-class) since Immutable is mixed into
    # the recordable, which has no reference to the Recording class itself.
    def self.destroying_recordable? = Thread.current[:recordables_destroying_recordable] || false

    class_methods do
      def record(recordable, actor:, parent: nil, **attributes)
        transaction do
          recordable.save!
          recording = create!(recordable: recordable, creator: actor, parent: parent, **attributes)
          recording.log!("created", recordable, actor: actor)
          recording
        end
      end
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

    # A real delete: removes this Recording and its recordable row. Events
    # are never touched here — recording_id is nullified (see the install
    # migration's foreign_key on_delete: :nullify), not cascaded, so the
    # log this recordable ever happened stays intact after the content
    # itself is gone. Logs a final "destroyed" event first, against the
    # recordable that's about to disappear, so the log itself says what was
    # removed and by whom.
    def destroy!(actor: nil)
      transaction do
        log!("destroyed", recordable, actor: actor)
        begin
          Thread.current[:recordables_destroying_recordable] = true
          recordable.destroy!
        ensure
          Thread.current[:recordables_destroying_recordable] = false
        end
        super()
      end
    end
  end
end
