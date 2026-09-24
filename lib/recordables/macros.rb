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

    # Raises if anything tries to write directly to a persisted recordable
    # row instead of going through revise()/destroy! on its Recording. See
    # Recordables::Immutable for the mechanics.
    #
    #   class RoutineTemplate < ApplicationRecord
    #     recordable
    #     immutable
    #   end
    def immutable
      include Recordables::Immutable
    end

    # Repoints real has_many associations (plain FK, not a child Recording)
    # at each new row a revision creates, instead of leaving them pointed
    # at what revise() just made obsolete. See Recordables::RepointOnRevise
    # for the mechanics.
    #
    #   class RoutineTemplate < ApplicationRecord
    #     recordable
    #     repoint_on_revise :routine_template_people
    #   end
    def repoint_on_revise(*association_names)
      include Recordables::RepointOnRevise
      self.repointed_association_names = association_names
    end

    # A recordable type whose Recording parents other Recordings — a Task
    # under its Routine. See Recordables::HasChildren for the mechanics.
    #
    #   class RoutineTemplate < ApplicationRecord
    #     recordable
    #     has_children :task_templates
    #   end
    def has_children(plural_name, class_name: nil)
      include Recordables::HasChildren
      __recordables_define_children(plural_name, class_name: class_name)
    end

    # The accepts_nested_attributes_for shape for a has_children
    # association — a fields_for form editing a recordable parent's
    # children. See Recordables::NestedRecordableAttributes for the
    # mechanics. Requires has_children for the same name first.
    #
    #   class RoutineTemplate < ApplicationRecord
    #     recordable
    #     has_children :task_templates, class_name: "TaskTemplate"
    #     nested_recordable_attributes_for :task_templates, class_name: "TaskTemplate",
    #       recording_attributes: ->(template) { { account: template.account } }
    #   end
    #
    # recording_attributes: only needed if the host app's Recording has its
    # own required columns (an account_id or similar tenant column is the
    # common case) — see Recordables::NestedRecordableAttributes.
    def nested_recordable_attributes_for(plural_name, class_name: nil, recording_attributes: nil)
      include Recordables::NestedRecordableAttributes
      target_class_name = class_name&.to_s || plural_name.to_s.classify
      __recordables_define_nested_attributes(plural_name, class_name: target_class_name, recording_attributes: recording_attributes)
    end

    # A belongs_to whose target is recordable, resolved through the append-only
    # Event log instead of the raw foreign key.
    #
    # Rails' belongs_to association reader builds its own `WHERE id = ...`
    # query directly against the target class — but revise() repoints a
    # Recording at a brand new row id, so a plain belongs_to holding the id
    # from whenever it was assigned silently returns the stale, superseded
    # row (or nil, if that row's since been destroyed) instead of the
    # current one. Never store or compare a recording_id directly for this
    # reason — always resolve through the recordable's own stable id, the
    # way this does.
    #
    # An Event's recordable_id is set once, at the moment that event
    # happened, and never rewritten — so the "created" event for a given
    # target id still names that id no matter how many times the target's
    # been revised since. That event's Recording is the stable pointer for
    # the whole lineage, so walking through it reaches whatever version is
    # current right now: the original row if it still is, or the latest
    # revision if the original has since been revised.
    #
    #   class Routine < ApplicationRecord
    #     recordable_belongs_to :routine_template
    #   end
    #
    # Accepts the same options as belongs_to (class_name, foreign_key,
    # optional, etc) and still defines the plain association under the hood
    # — for eager loading, FK validation, forms — only the reader method is
    # overridden.
    def recordable_belongs_to(name, class_name: nil, foreign_key: nil, **options)
      belongs_to name, class_name: class_name, foreign_key: foreign_key, **options

      target_class_name = class_name&.to_s || name.to_s.camelize
      fk = foreign_key&.to_s || "#{name}_id"

      define_method(name) do
        id = public_send(fk)
        next nil if id.blank?

        ::Event.where(recordable_type: target_class_name, recordable_id: id)
               .first&.recording&.recordable
      end
    end
  end
end
