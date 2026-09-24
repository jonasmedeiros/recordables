require "test_helper"

class RecordingTest < RecordablesTest
  def test_record_creates_the_recordable_and_logs_an_event
    recording = Recording.record(Post.new(title: "First"), actor: actor)

    assert_predicate recording, :persisted?
    assert_equal "Post", recording.recordable_type
    assert_equal 1, recording.events.count
    assert_equal "created", recording.events.first.action
    assert_equal actor, recording.events.first.actor
  end

  def test_record_accepts_a_bucket_and_a_parent
    bucket = Bucket.create!(bucketable: Project.create!(name: "Launch"))
    parent = Recording.record(Post.new(title: "Parent"), actor: actor, bucket: bucket)
    child = Recording.record(Note.new(body: "Child"), actor: actor, bucket: bucket, parent: parent)

    assert_equal bucket, child.bucket
    assert_equal parent, child.parent
    assert_equal [child], parent.children.to_a
  end

  def test_revise_inserts_a_new_snapshot_and_moves_the_pointer
    recording = Recording.record(Post.new(title: "First"), actor: actor)
    original_id = recording.recordable_id

    revision = recording.revise(actor: actor, title: "Second")

    assert_equal "Second", revision.title
    refute_equal original_id, recording.reload.recordable_id
    assert_equal 2, Post.count, "the original snapshot must survive"
    assert_equal 1, Recording.count
  end

  def test_revise_never_mutates_the_previous_snapshot
    recording = Recording.record(Post.new(title: "First"), actor: actor)
    original = recording.recordable

    recording.revise(actor: actor, title: "Second")

    assert_equal "First", original.reload.title
  end

  def test_versions_lists_every_snapshot_in_order
    recording = Recording.record(Post.new(title: "v1"), actor: actor)
    recording.revise(actor: actor, title: "v2")
    recording.revise(actor: actor, title: "v3")

    assert_equal %w[created updated updated], recording.versions.map(&:action)
    assert_equal %w[v1 v2 v3], recording.versions.map { |event| event.recordable.title }
  end

  def test_recordable_at_returns_the_snapshot_current_at_that_time
    recording = Recording.record(Post.new(title: "v1"), actor: actor)
    between = Time.current
    sleep 0.01
    recording.revise(actor: actor, title: "v2")

    assert_equal "v1", recording.recordable_at(between).title
    assert_equal "v2", recording.reload.recordable.title
  end

  def test_recordable_at_returns_nil_before_the_first_version
    recording = Recording.record(Post.new(title: "v1"), actor: actor)

    assert_nil recording.recordable_at(1.day.ago)
  end

  def test_revert_to_moves_the_pointer_without_deleting_anything
    recording = Recording.record(Post.new(title: "v1"), actor: actor)
    first = recording.recordable
    recording.revise(actor: actor, title: "v2")

    recording.revert_to(first, actor: actor)

    assert_equal "v1", recording.reload.recordable.title
    assert_equal 2, Post.count
    assert_equal "reverted", recording.versions.last.action
  end

  def test_revert_is_itself_recorded_as_history
    recording = Recording.record(Post.new(title: "v1"), actor: actor)
    first = recording.recordable
    recording.revise(actor: actor, title: "v2")
    recording.revert_to(first, actor: actor)

    assert_equal 3, recording.versions.count
  end

  def test_revise_records_which_fields_changed
    recording = Recording.record(Post.new(title: "v1"), actor: actor)
    recording.revise(actor: actor, title: "v2")

    assert_equal({ "changed" => ["title"] }, recording.versions.last.details)
  end

  def test_a_failed_revision_leaves_the_pointer_alone
    recording = Recording.record(Post.new(title: "v1"), actor: actor)
    original_id = recording.recordable_id

    assert_raises(ActiveRecord::RecordInvalid) { recording.revise(actor: actor, title: nil) }
    assert_equal original_id, recording.reload.recordable_id
    assert_equal 1, Post.count
  end

  def test_one_feed_spans_every_type
    Recording.record(Post.new(title: "a post"), actor: actor)
    Recording.record(Note.new(body: "a note"), actor: actor)

    assert_equal %w[Note Post], Event.distinct.pluck(:recordable_type).sort
  end

  def test_delegated_type_scopes_and_predicates
    Recording.record(Post.new(title: "a post"), actor: actor)
    Recording.record(Note.new(body: "a note"), actor: actor)

    assert_equal 1, Recording.posts.count
    assert_predicate Recording.posts.first, :post?
    refute_predicate Recording.posts.first, :note?
  end

  def test_destroy_bang_removes_the_recording_and_its_recordable
    recording = Recording.record(Post.new(title: "v1"), actor: actor)
    post_id = recording.recordable_id

    recording.destroy!(actor: actor)

    refute Recording.exists?(recording.id)
    refute Post.exists?(post_id)
  end

  def test_destroy_bang_leaves_every_prior_event_in_place
    recording = Recording.record(Post.new(title: "v1"), actor: actor)
    recording.revise(actor: actor, title: "v2")
    event_ids = recording.events.pluck(:id)

    recording.destroy!(actor: actor)

    assert_equal event_ids.sort, Event.where(id: event_ids).pluck(:id).sort
  end

  def test_destroy_bang_nullifies_recording_id_on_its_events_instead_of_deleting_them
    recording = Recording.record(Post.new(title: "v1"), actor: actor)
    event_ids = recording.events.pluck(:id)

    recording.destroy!(actor: actor)

    assert_equal [nil], Event.where(id: event_ids).distinct.pluck(:recording_id)
  end

  def test_destroy_bang_logs_a_destroyed_event_naming_the_actor
    recording = Recording.record(Post.new(title: "v1"), actor: actor)

    recording.destroy!(actor: actor)

    destroyed_event = Event.where(recordable_type: "Post").order(:created_at).last
    assert_equal "destroyed", destroyed_event.action
    assert_equal actor, destroyed_event.actor
  end

  def test_an_events_actor_name_survives_the_actor_being_deleted
    deletable_actor = User.create!(name: "Temp Person")
    recording = Recording.record(Post.new(title: "v1"), actor: deletable_actor)
    event = recording.events.first

    deletable_actor.destroy!

    assert_nil event.reload.actor
    assert_equal "Temp Person", event.actor_name
    assert_equal "Temp Person", event.actor_label
  end
end
