require "active_support/concern"

module Recordables
  module Recordable
    extend ActiveSupport::Concern

    # Raised when a snapshot owns associations the copy-forward cannot carry.
    # Losing them silently is the failure this gem exists to prevent.
    class UncopyableAssociation < StandardError; end

    included do
      has_many :recordings, as: :recordable
      has_many :events, as: :recordable
    end

    def commentable? = false
    def publishable? = false
    def nestable? = false

    def summary = model_name.human

    def revisable_attributes = attributes.except("id", "created_at")

    # Column values ride along in #attributes, but rich text and attached files
    # live in their own tables and would vanish from a new snapshot in silence.
    def copy_content_to(revision)
      guard_uncopyable_associations!
      copy_rich_text_to(revision)
      copy_attachments_to(revision)
      revision
    end

    private

      def guard_uncopyable_associations!
        names = uncopyable_association_names
        return if names.empty?

        raise UncopyableAssociation,
              "#{self.class.name} owns #{names.join(', ')}, which a new snapshot cannot carry. " \
              "Model these as child recordings, or override #copy_content_to."
      end

      def uncopyable_association_names
        self.class.reflect_on_all_associations.filter_map do |reflection|
          next if reflection.options[:class_name] == "ActionText::RichText"
          next if reflection.name.to_s.start_with?("rich_text_")
          next unless %i[has_many has_one].include?(reflection.macro)
          next if %i[recordings events].include?(reflection.name)
          next if attachment_reflection_names.include?(reflection.name)

          reflection.name
        end
      end

      def attachment_reflection_names
        return [] unless self.class.respond_to?(:attachment_reflections)

        self.class.attachment_reflections.flat_map do |name, _reflection|
          [name.to_sym, :"#{name}_attachment", :"#{name}_attachments", :"#{name}_blob", :"#{name}_blobs"]
        end
      end

      def rich_text_names
        self.class.reflect_on_all_associations(:has_one)
            .select { |reflection| reflection.options[:class_name] == "ActionText::RichText" }
            .map { |reflection| reflection.name.to_s.delete_prefix("rich_text_") }
      end

      def copy_rich_text_to(revision)
        rich_text_names.each do |name|
          existing = public_send(name)
          revision.public_send(:"#{name}=", existing.body) if existing&.body
        end
      end

      def copy_attachments_to(revision)
        return unless self.class.respond_to?(:attachment_reflections)

        self.class.attachment_reflections.each do |name, reflection|
          attached = public_send(name)
          next unless attached.attached?

          blobs = reflection.macro == :has_many_attached ? attached.blobs : [attached.blob]
          revision.public_send(name).attach(*blobs)
        end
      end
  end
end
