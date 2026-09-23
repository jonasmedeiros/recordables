require "active_support/concern"

module Recordables
  # Opt-in alongside `recordable` for a type whose Recording parents other
  # Recordings — a Task under its Routine, a TaskTemplate under its
  # RoutineTemplate. Not a real has_many: a child's own Recording carries
  # the parent link (parent_id), not a foreign key on the child row itself
  # — a plain FK would silently orphan every child the moment its parent
  # is revised, since revise() replaces the parent row with a new id.
  #
  #   class RoutineTemplate < ApplicationRecord
  #     recordable
  #     has_children :task_templates, class_name: "TaskTemplate"
  #   end
  #
  # Defines two methods per name:
  #
  #   template.task_templates
  #     # => current children, ordered
  #   template.add_task_template(actor:, recording: {}, **attrs)
  #     # => Recording.record(TaskTemplate.new(attrs), actor:, parent:, **recording)
  #
  # Read-heavy chaining (.count, .where, .order, .each, .find, ...) works
  # the same as a real has_many. Building/creating a child goes through
  # add_* instead — "create a child" is a recording operation (it needs
  # its own Recording, parented to this one), not a plain attribute
  # assignment a bare .build could do.
  #
  # attrs become the child model's own attributes; recording: carries
  # anything that belongs on the Recording itself instead (account:,
  # bucket:, or any other extra column the host app's Recording has) —
  # kept as an explicit, separate argument rather than guessed at by
  # inspecting attrs, since a model attribute happening to share a name
  # with a Recording column would otherwise route to the wrong place
  # silently.
  module HasChildren
    extend ActiveSupport::Concern

    class_methods do
      def __recordables_define_children(plural_name, class_name: nil)
        singular_name = plural_name.to_s.singularize
        target_class_name = class_name&.to_s || plural_name.to_s.classify

        define_method(plural_name) do
          target = target_class_name.constantize
          return target.none unless recording

          target.joins(:recordings).merge(::Recording.active.where(parent_id: recording.id))
                .order("recordings.position")
        end

        define_method(:"add_#{singular_name}") do |actor: nil, recording: {}, **attrs|
          target = target_class_name.constantize

          ::Recording.record(target.new(attrs), actor: actor, parent: self.recording, **recording)
        end
      end
    end
  end
end
