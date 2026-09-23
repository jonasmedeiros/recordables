require "test_helper"

class TrashableTest < RecordablesTest
  def test_a_trashed_recordings_row_is_invisible_to_plain_queries
    recording = Recording.record(Topic.new(title: "First"), actor: actor)
    topic = recording.recordable

    recording.trash!(actor: actor)

    refute_includes Topic.all.to_a, topic
    assert_nil Topic.find_by(id: topic.id)
  end

  def test_with_trashed_still_sees_it
    recording = Recording.record(Topic.new(title: "First"), actor: actor)
    topic = recording.recordable

    recording.trash!(actor: actor)

    assert_includes Topic.with_trashed.to_a, topic
  end

  def test_trash_logs_an_event_and_does_not_delete_the_row
    recording = Recording.record(Topic.new(title: "First"), actor: actor)

    recording.trash!(actor: actor)

    assert_equal 1, Topic.with_trashed.count
    assert_equal "trashed", recording.events.order(:created_at).last.action
  end

  def test_active_scope_excludes_trashed_recordings
    active = Recording.record(Topic.new(title: "Active"), actor: actor)
    trashed = Recording.record(Topic.new(title: "Trashed"), actor: actor)
    trashed.trash!(actor: actor)

    assert_includes Recording.active.to_a, active
    refute_includes Recording.active.to_a, trashed
  end

  def test_revising_leaves_the_row_visible_since_the_recording_stays_active
    recording = Recording.record(Topic.new(title: "First"), actor: actor)

    recording.revise(actor: actor, title: "Second")

    assert_equal "Second", Topic.find(recording.recordable_id).title
  end

  def test_bare_delete_all_raises_since_it_would_silently_skip_trashed_rows
    Recording.record(Topic.new(title: "First"), actor: actor)

    assert_raises(Recordables::AmbiguousBulkDelete) { Topic.delete_all }
  end

  def test_bare_destroy_all_raises_since_it_would_silently_skip_trashed_rows
    Recording.record(Topic.new(title: "First"), actor: actor)

    assert_raises(Recordables::AmbiguousBulkDelete) { Topic.destroy_all }
  end

  def test_with_trashed_delete_all_actually_clears_the_table
    recording = Recording.record(Topic.new(title: "First"), actor: actor)
    recording.trash!(actor: actor)

    Topic.with_trashed.delete_all

    assert_equal 0, Topic.with_trashed.count
  end

  def test_scoped_delete_all_still_works_without_raising
    Recording.record(Topic.new(title: "Keep"), actor: actor)
    Recording.record(Topic.new(title: "Drop"), actor: actor)

    Topic.where(title: "Drop").delete_all

    assert_equal ["Keep"], Topic.pluck(:title)
  end
end
