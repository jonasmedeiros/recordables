require "test_helper"

class RecordableTest < RecordablesTest
  def test_capability_defaults_are_false_so_types_must_opt_in
    assert_predicate Post.new, :commentable?
    refute_predicate Note.new, :commentable?
    refute_predicate Note.new, :publishable?
    refute_predicate Note.new, :nestable?
  end

  def test_revisable_attributes_drops_identity_and_timestamp
    post = Post.create!(title: "First")

    refute_includes post.revisable_attributes.keys, "id"
    refute_includes post.revisable_attributes.keys, "created_at"
    assert_includes post.revisable_attributes.keys, "title"
  end

  def test_copy_content_to_is_a_no_op_for_plain_column_models
    post = Post.create!(title: "First")
    revision = Post.new(title: "Second")

    assert_equal revision, post.copy_content_to(revision)
  end

  def test_revise_refuses_when_a_snapshot_owns_an_uncopyable_association
    recording = Recording.record(Draft.new(title: "First"), actor: actor)

    error = assert_raises(Recordables::Recordable::UncopyableAssociation) do
      recording.revise(actor: actor, title: "Second")
    end

    assert_match(/tags/, error.message)
    assert_match(/child recordings/, error.message)
  end

  def test_the_refusal_leaves_the_pointer_untouched
    recording = Recording.record(Draft.new(title: "First"), actor: actor)
    original_id = recording.recordable_id

    assert_raises(Recordables::Recordable::UncopyableAssociation) do
      recording.revise(actor: actor, title: "Second")
    end

    assert_equal original_id, recording.reload.recordable_id
    assert_equal 1, Draft.count
  end

  def test_the_recordings_and_events_associations_do_not_trip_the_guard
    recording = Recording.record(Post.new(title: "First"), actor: actor)

    assert_equal "Second", recording.revise(actor: actor, title: "Second").title
  end

  def test_recording_returns_the_recording_currently_pointing_at_this_row
    recording = Recording.record(Post.new(title: "First"), actor: actor)

    assert_equal recording, recording.recordable.recording
  end
end
