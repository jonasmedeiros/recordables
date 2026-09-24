require "test_helper"
require "rails/generators/test_case"
require "generators/recordables/install/install_generator"
require "generators/recordables/type/type_generator"
require "generators/recordables/bucket/bucket_generator"
require "generators/recordables/backfill/backfill_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests Recordables::Generators::InstallGenerator
  destination File.expand_path("../tmp/generated", __dir__)
  setup :prepare_destination

  def test_it_generates_the_spine_and_the_bucket_by_default
    run_generator

    assert_file "app/models/recording.rb", /records :recordable, types: Recordable::TYPES/
    assert_file "app/models/event.rb", /belongs_to :recording, optional: true/
    assert_file "app/models/event.rb", /belongs_to :actor, class_name: "User", optional: true/
    assert_file "app/models/event.rb", /actor&\.name \|\| actor_name/
    assert_file "app/models/concerns/recordable.rb", /TYPES = %w\[\]/
    assert_file "app/models/bucket.rb", /delegated_type :bucketable/
    assert_file "app/models/concerns/bucketable.rb", /TYPES = %w\[\]/
    assert_migration "db/migrate/create_recordables_tables.rb" do |migration|
      assert_match(/create_table :buckets/, migration)
      refute_match(/:status/, migration)
      assert_match(/t\.string :actor_name/, migration)
      assert_match(/on_delete: :nullify/, migration)
    end
  end

  def test_actor_label_is_configurable
    run_generator %w[--actor-label=display_name]

    assert_file "app/models/event.rb", /actor&\.display_name \|\| actor_name/
  end

  def test_skipping_buckets_omits_them_everywhere
    run_generator %w[--skip-buckets]

    assert_no_file "app/models/bucket.rb"
    assert_no_file "app/models/concerns/bucketable.rb"
    assert_migration "db/migrate/create_recordables_tables.rb" do |migration|
      refute_match(/create_table :buckets/, migration)
      refute_match(/t.references :bucket/, migration)
    end
  end

  def test_the_actor_model_is_configurable
    run_generator %w[--actor=Person]

    assert_file "app/models/recording.rb", /class_name: "Person"/
    assert_file "app/models/event.rb", /class_name: "Person"/
    assert_migration "db/migrate/create_recordables_tables.rb", /to_table: :people/
  end

  def test_it_refuses_an_invalid_actor_name
    output = capture(:stderr) { run_generator ["--actor=bad name"] }

    assert_match(/Invalid --actor/, output)
    assert_no_file "app/models/recording.rb"
  end
end

class TypeGeneratorTest < Rails::Generators::TestCase
  tests Recordables::Generators::TypeGenerator
  destination File.expand_path("../tmp/generated", __dir__)
  setup :prepare_destination

  def test_it_generates_an_immutable_type_and_registers_it
    install
    run_generator %w[Article title:string]

    assert_file "app/models/article.rb", /recordable/
    assert_file "app/models/article.rb", /validates :title, presence: true/
    assert_file "app/models/concerns/recordable.rb", /TYPES = %w\[Article\]/
    assert_migration "db/migrate/create_articles.rb" do |migration|
      assert_match(/t.string :title/, migration)
      refute_match(/updated_at/, migration)
    end
  end

  def test_registering_a_second_type_keeps_the_first
    install
    run_generator %w[Article title:string]
    run_generator %w[Note body:text]

    assert_file "app/models/concerns/recordable.rb", /TYPES = %w\[Article Note\]/
  end

  def test_registering_the_same_type_twice_does_not_duplicate_it
    install
    run_generator %w[Article title:string]
    run_generator %w[Article title:string]

    assert_file "app/models/concerns/recordable.rb", /TYPES = %w\[Article\]/
  end

  def test_a_text_field_becomes_a_truncated_summary
    install
    run_generator %w[Note body:text]

    assert_file "app/models/note.rb", /def summary = body.truncate\(40\)/
  end

  def test_it_refuses_an_invalid_class_name
    install

    output = capture(:stderr) { run_generator ["Some Bad Name"] }

    assert_match(/Invalid name/, output)
    assert_no_file "app/models/some bad name.rb"
    assert_file "app/models/concerns/recordable.rb", /TYPES = %w\[\]/
  end

  private

    def install
      Recordables::Generators::InstallGenerator.start([], destination_root: destination_root)
    end
end

class BucketGeneratorTest < Rails::Generators::TestCase
  tests Recordables::Generators::BucketGenerator
  destination File.expand_path("../tmp/generated", __dir__)
  setup :prepare_destination

  def test_it_generates_a_bucket_type_and_registers_it
    Recordables::Generators::InstallGenerator.start([], destination_root: destination_root)
    run_generator %w[Project name:string]

    assert_file "app/models/project.rb", /include Bucketable/
    assert_file "app/models/concerns/bucketable.rb", /TYPES = %w\[Project\]/
    assert_migration "db/migrate/create_projects.rb", /t.string :name/
  end

  def test_it_refuses_an_invalid_class_name
    Recordables::Generators::InstallGenerator.start([], destination_root: destination_root)

    output = capture(:stderr) { run_generator ["bad name"] }

    assert_match(/Invalid name/, output)
    assert_file "app/models/concerns/bucketable.rb", /TYPES = %w\[\]/
  end
end

class BackfillGeneratorTest < Rails::Generators::TestCase
  tests Recordables::Generators::BackfillGenerator
  destination File.expand_path("../tmp/generated", __dir__)
  setup :prepare_destination

  def test_it_scaffolds_a_migration_that_creates_a_recording_for_every_row
    run_generator %w[RoutineTemplate]

    assert_migration "db/migrate/backfill_routine_templates_recordings.rb" do |migration|
      assert_match(/RoutineTemplate\.find_each/, migration)
      assert_match(/Recording\.record\(/, migration)
    end
  end

  def test_creator_and_account_options_are_used_verbatim
    run_generator %w[RoutineTemplate --creator=person_id --account=account_id]

    assert_migration "db/migrate/backfill_routine_templates_recordings.rb" do |migration|
      assert_match(/actor: routine_template\.person_id/, migration)
      assert_match(/account: routine_template\.account_id/, migration)
    end
  end

  def test_defaults_to_actor_and_account_when_options_are_omitted
    run_generator %w[RoutineTemplate]

    assert_migration "db/migrate/backfill_routine_templates_recordings.rb" do |migration|
      assert_match(/actor: routine_template\.actor/, migration)
      assert_match(/account: routine_template\.account/, migration)
    end
  end

  def test_the_down_migration_cleans_up_the_recordings_it_created
    run_generator %w[RoutineTemplate]

    assert_migration "db/migrate/backfill_routine_templates_recordings.rb" do |migration|
      assert_match(/def down/, migration)
      assert_match(/Recording\.where\(recordable_type: "RoutineTemplate"\)\.find_each/, migration)
    end
  end

  def test_it_refuses_an_invalid_class_name
    output = capture(:stderr) { run_generator ["bad name"] }

    assert_match(/Invalid name/, output)
    assert_no_migration "db/migrate/backfill_bad names_recordings.rb"
  end
end
