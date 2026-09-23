require "test_helper"

class ImmutableTest < RecordablesTest
  def test_update_bang_on_a_persisted_row_raises
    recording = Recording.record(Topic.new(title: "First"), actor: actor)
    topic = recording.recordable

    assert_raises(Recordables::ImmutableRecordable) { topic.update!(title: "Second") }
  end

  def test_update_on_a_persisted_row_raises
    recording = Recording.record(Topic.new(title: "First"), actor: actor)
    topic = recording.recordable

    assert_raises(Recordables::ImmutableRecordable) { topic.update(title: "Second") }
  end

  def test_saving_changed_attributes_on_a_persisted_row_raises
    recording = Recording.record(Topic.new(title: "First"), actor: actor)
    topic = recording.recordable
    topic.title = "Second"

    assert_raises(Recordables::ImmutableRecordable) { topic.save! }
  end

  def test_update_column_raises
    recording = Recording.record(Topic.new(title: "First"), actor: actor)
    topic = recording.recordable

    assert_raises(Recordables::ImmutableRecordable) { topic.update_column(:title, "Second") }
  end

  def test_update_columns_raises
    recording = Recording.record(Topic.new(title: "First"), actor: actor)
    topic = recording.recordable

    assert_raises(Recordables::ImmutableRecordable) { topic.update_columns(title: "Second") }
  end

  def test_destroy_raises
    recording = Recording.record(Topic.new(title: "First"), actor: actor)
    topic = recording.recordable

    assert_raises(Recordables::ImmutableRecordable) { topic.destroy }
  end

  def test_delete_raises
    recording = Recording.record(Topic.new(title: "First"), actor: actor)
    topic = recording.recordable

    assert_raises(Recordables::ImmutableRecordable) { topic.delete }
  end

  def test_class_level_update_all_raises
    Recording.record(Topic.new(title: "First"), actor: actor)

    assert_raises(Recordables::ImmutableRecordable) { Topic.update_all(title: "Second") }
  end

  def test_the_initial_save_through_record_is_not_blocked
    recording = Recording.record(Topic.new(title: "First"), actor: actor)

    assert_equal "First", recording.recordable.title
  end

  def test_revise_is_not_blocked_since_it_saves_a_fresh_row
    recording = Recording.record(Topic.new(title: "First"), actor: actor)

    revision = recording.revise(actor: actor, title: "Second")

    assert_equal "Second", revision.title
  end

  def test_trash_is_not_blocked_since_it_writes_to_the_recording_not_the_row
    recording = Recording.record(Topic.new(title: "First"), actor: actor)

    recording.trash!(actor: actor)

    assert_predicate recording.reload, :trashed?
  end
end
