require "active_support/concern"

module Recordables
  # Opt-in alongside `has_children` for the accepts_nested_attributes_for
  # shape (a form with fields_for) on a recordable parent's children.
  #
  #   class RoutineTemplate < ApplicationRecord
  #     recordable
  #     has_children :task_templates, class_name: "TaskTemplate"
  #     nested_recordable_attributes_for :task_templates, class_name: "TaskTemplate"
  #   end
  #
  # accepts_nested_attributes_for can't work here: it writes at
  # assign_attributes time, straight to a real association's rows — but
  # task_templates isn't a real has_many (see HasChildren), and a child
  # needs its own Recording the moment it's created, which a plain
  # attribute assignment can't set up. This does the same job (a form
  # posts an array of {id:, ...fields, _destroy:} hashes; existing rows
  # get updated or trashed, new ones get created) through revise()/trash!
  # instead of a raw write.
  #
  # Two-phase, same as accepts_nested_attributes_for from the caller's
  # side but not under the hood: fields_for-style form submission first
  # calls #{plural}_attributes= (stores the raw rows, writes nothing yet),
  # then the interactor/controller explicitly calls
  # apply_#{plural}_attributes! once the parent itself is saved/revised —
  # a new child needs a *current* Recording to parent under, which only
  # exists after that.
  module NestedRecordableAttributes
    extend ActiveSupport::Concern

    class_methods do
      def __recordables_define_nested_attributes(plural_name, class_name:)
        singular_name = plural_name.to_s.singularize
        target_class_name = class_name.to_s
        pending_ivar = :"@pending_#{plural_name}_attributes"
        rendered_ivar = :"@rendered_#{plural_name}"

        attr_reader :"pending_#{plural_name}_attributes"

        define_method(:"#{plural_name}_attributes=") do |attributes|
          instance_variable_set(pending_ivar, attributes.is_a?(Hash) ? attributes.values : attributes)
        end

        # Blank row for an "add" button in the form — mirrors what
        # `children.build` would do on a real has_many. In-memory only.
        define_method(:"build_#{singular_name}") do
          send(:"rendered_#{plural_name}") << target_class_name.constantize.new
        end

        # What the form actually iterates via fields_for: the just-submitted
        # rows if the form was just posted (so a validation error re-renders
        # what the user typed, the same as accepts_nested_attributes_for
        # would), otherwise the persisted children.
        define_method(:"rendered_#{plural_name}") do
          instance_variable_get(rendered_ivar) || instance_variable_set(rendered_ivar, begin
            pending = instance_variable_get(pending_ivar)

            if pending
              pending.filter_map do |attrs|
                attrs = attrs.to_h.symbolize_keys
                next if ActiveModel::Type::Boolean.new.cast(attrs[:_destroy])

                target_class_name.constantize.new(attrs.except(:id, :_destroy))
              end
            else
              public_send(plural_name).to_a
            end
          end)
        end

        define_method(:"apply_#{plural_name}_attributes!") do |actor: nil|
          pending = instance_variable_get(pending_ivar)
          next unless pending

          current_by_id = public_send(plural_name).index_by { |child| child.id.to_s }

          pending.each do |attrs|
            attrs = attrs.to_h.symbolize_keys
            id = attrs[:id].presence
            destroy = ActiveModel::Type::Boolean.new.cast(attrs[:_destroy])
            changes = attrs.except(:id, :_destroy)

            if id && (child = current_by_id[id.to_s])
              if destroy
                child.recording.trash!(actor: actor)
              else
                child.recording.revise(actor: actor, **changes)
              end
            elsif !destroy && changes.present?
              public_send(:"add_#{singular_name}", actor: actor, **changes)
            end
          end

          instance_variable_set(pending_ivar, nil)
        end
      end
    end
  end
end
