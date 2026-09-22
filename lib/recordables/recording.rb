require "active_support/concern"

module Recordables
  module Recording
    extend ActiveSupport::Concern

    VERSION_ACTIONS = %w[created updated reverted].freeze

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
  end
end
