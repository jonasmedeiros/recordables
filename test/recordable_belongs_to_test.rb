require "test_helper"

class RecordableBelongsToTest < RecordablesTest
  def test_resolves_directly_when_the_target_has_never_been_revised
    recording = Recording.record(Topic.new(title: "First"), actor: actor)
    topic = recording.recordable
    tag = Tag.create!(topic_id: topic.id, name: "roadmap")

    assert_equal topic.id, tag.topic.id
  end

  def test_resolves_to_the_current_version_after_the_target_has_been_revised
    recording = Recording.record(Topic.new(title: "First"), actor: actor)
    topic = recording.recordable
    tag = Tag.create!(topic_id: topic.id, name: "roadmap")

    revised = recording.revise(actor: actor, title: "Second")

    # Regression: a plain `belongs_to :topic` would return the original,
    # now-superseded row here (Rails builds `WHERE id = ...` directly
    # against whatever id was assigned) instead of the current version.
    assert_equal revised.id, tag.topic.id
    assert_equal "Second", tag.topic.title
  end

  def test_resolves_to_the_latest_of_several_revisions
    recording = Recording.record(Topic.new(title: "v1"), actor: actor)
    topic = recording.recordable
    tag = Tag.create!(topic_id: topic.id, name: "roadmap")

    recording.revise(actor: actor, title: "v2")
    latest = recording.revise(actor: actor, title: "v3")

    assert_equal latest.id, tag.topic.id
    assert_equal "v3", tag.topic.title
  end

  def test_returns_nil_when_the_foreign_key_is_blank
    tag = Tag.create!(topic_id: nil, name: "roadmap")

    assert_nil tag.topic
  end

  def test_still_defines_the_plain_association_for_eager_loading_and_forms
    recording = Recording.record(Topic.new(title: "First"), actor: actor)
    tag = Tag.create!(topic_id: recording.recordable_id, name: "roadmap")

    assert_respond_to tag, :topic_id
    loaded = Tag.includes(:topic).find(tag.id)
    assert_equal tag.topic_id, loaded.topic_id
  end
end
