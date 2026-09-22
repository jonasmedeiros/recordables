require "rails/generators"
require "rails/generators/active_record"
require "recordables/generator_helpers"

module Recordables
  module Generators
    class BucketGenerator < Rails::Generators::NamedBase
      include ActiveRecord::Generators::Migration
      include Recordables::GeneratorHelpers

      source_root File.expand_path("templates", __dir__)

      desc "Generate a bucket type — a container that owns recordings and defines access."

      def validate!
        validate_name!
      end

      def create_model
        template "model.rb.tt", File.join("app/models", class_path, "#{file_name}.rb")
      end

      def create_bucket_migration
        migration_template "migration.rb.tt", "db/migrate/create_#{table_name}.rb"
      end

      def register_type
        register_type_in "app/models/concerns/bucketable.rb", "TYPES"
      end

      private

        def generator_example = "bin/rails generate recordables:bucket Project name:string"
    end
  end
end
