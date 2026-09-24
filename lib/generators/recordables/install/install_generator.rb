require "rails/generators"
require "rails/generators/active_record"
require "recordables/generator_helpers"

module Recordables
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Generate the recordings/events spine, and optionally the bucket container."

      class_option :actor, type: :string, default: "User",
                           desc: "Model that creates recordings and appears on events"
      class_option :actor_label, type: :string, default: "name",
                           desc: "Attribute on the actor to snapshot onto events, e.g. name or display_name"
      class_option :buckets, type: :boolean, default: true,
                            desc: "Generate Bucket, the container that owns recordings"

      def validate!
        return if actor_class.match?(Recordables::GeneratorHelpers::CONSTANT_NAME)

        raise Rails::Generators::Error,
              "Invalid --actor #{options[:actor].inspect}. Give a single CamelCase class name, " \
              "for example: --actor=Person"
      end

      def create_spine_migration
        migration_template "create_recordables_tables.rb.tt", "db/migrate/create_recordables_tables.rb"
      end

      def create_models
        template "recording.rb.tt", "app/models/recording.rb"
        template "event.rb.tt", "app/models/event.rb"
        template "recordable.rb.tt", "app/models/concerns/recordable.rb"
        return unless buckets?

        template "bucket.rb.tt", "app/models/bucket.rb"
        template "bucketable.rb.tt", "app/models/concerns/bucketable.rb"
      end

      def report
        say "\nNext:", :green
        say "  bin/rails generate recordables:bucket Project name:string" if buckets?
        say "  bin/rails generate recordables:type Article title:string"
      end

      private

        def buckets? = options[:buckets]

        def actor_class = options[:actor].camelize

        def actor_table = actor_class.tableize

        def actor_label = options[:actor_label]

        def migration_version = "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
    end
  end
end
