module Recordables
  module GeneratorHelpers
    CONSTANT_NAME = /\A[A-Z][A-Za-z0-9]*(::[A-Z][A-Za-z0-9]*)*\z/

    def self.included(base)
      base.argument :attributes, type: :array, default: [], banner: "field:type field:type"
    end

    def validate_name!
      return if class_name.match?(CONSTANT_NAME)

      raise Rails::Generators::Error,
            "Invalid name #{name.inspect}. Give a single CamelCase class name, " \
            "then the fields — for example: #{generator_example}"
    end

    private

      def register_type_in(concern, constant)
        unless File.exist?(File.join(destination_root, concern))
          say_status :skip, "#{concern} not found — run recordables:install first", :red
          return
        end

        gsub_file concern, /#{constant} = %w\[[^\]]*\]/ do |match|
          names = (match[/\[([^\]]*)\]/, 1].to_s.split + [class_name]).uniq
          "#{constant} = %w[#{names.join(' ')}]"
        end
      end

      def migration_version = "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
  end
end
