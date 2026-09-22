require "rails/generators"
require "rails/generators/active_record"
require "recordables/generator_helpers"

module Recordables
  module Generators
    class TypeGenerator < Rails::Generators::NamedBase
      include ActiveRecord::Generators::Migration
      include Recordables::GeneratorHelpers

      source_root File.expand_path("templates", __dir__)

      desc "Generate an immutable recordable type and register it with the Recordable concern."

      def validate!
        validate_name!
      end

      def create_model
        template "model.rb.tt", File.join("app/models", class_path, "#{file_name}.rb")
      end

      def create_type_migration
        migration_template "migration.rb.tt", "db/migrate/create_#{table_name}.rb"
      end

      def register_type
        register_type_in "app/models/concerns/recordable.rb", "TYPES"
      end

      private

        def generator_example = "bin/rails generate recordables:type Article title:string"

        def summary_expression
          attribute = attributes.find { |candidate| candidate.type == :string } ||
                      attributes.find { |candidate| candidate.type == :text }
          return "model_name.human" unless attribute

          attribute.type == :text ? "#{attribute.name}.truncate(40)" : attribute.name
        end
    end
  end
end
