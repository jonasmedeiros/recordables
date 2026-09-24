require "rails/generators"
require "rails/generators/active_record"
require "recordables/generator_helpers"

module Recordables
  module Generators
    # Scaffolds the migration for adopting recordable on a table that
    # already has rows: create the first Recording (and "created" Event)
    # for each one.
    #
    #   bin/rails generate recordables:backfill RoutineTemplate
    class BackfillGenerator < Rails::Generators::NamedBase
      include ActiveRecord::Generators::Migration
      include Recordables::GeneratorHelpers

      source_root File.expand_path("templates", __dir__)

      desc "Generate a migration that backfills the first Recording for every existing row of a type."

      class_option :creator, type: :string, default: nil,
                             desc: "Attribute on the row holding who created it, e.g. person_id"
      class_option :account, type: :string, default: nil,
                             desc: "Attribute on the row holding its account/tenant, e.g. account_id"

      def validate!
        validate_name!
      end

      def create_backfill_migration
        migration_template "backfill_migration.rb.tt", "db/migrate/backfill_#{table_name}_recordings.rb"
      end

      private

        def generator_example = "bin/rails generate recordables:backfill RoutineTemplate"

        def creator_expression
          options[:creator].presence || "actor"
        end

        def account_expression
          options[:account].presence || "account"
        end
    end
  end
end
