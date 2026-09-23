require "test_helper"

class TestingTest < RecordablesTest
  def test_current_recordable_resolves_through_the_recording_not_the_stale_row
    recording = Recording.record(Topic.new(title: "First"), actor: actor)
    topic = recording.recordable

    recording.revise(actor: actor, title: "Second")

    # Regression: topic.reload would silently return "First" here — it
    # re-fetches by topic's own, now-superseded primary key. Resolving
    # through the Recording (whose id never changes) is the fix.
    assert_equal "Second", current_recordable(recording).title
    refute_equal "Second", topic.reload.title
  end

  def test_accepts_a_recording_id_as_well_as_a_recording
    recording = Recording.record(Topic.new(title: "First"), actor: actor)
    recording.revise(actor: actor, title: "Second")

    assert_equal "Second", current_recordable(recording.id).title
  end

  def test_resolves_directly_when_nothing_has_been_revised
    recording = Recording.record(Topic.new(title: "First"), actor: actor)

    assert_equal "First", current_recordable(recording).title
  end
end
