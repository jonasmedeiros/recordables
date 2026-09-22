require "test_helper"

class RichTextTest < RecordablesTest
  def test_rich_text_is_carried_onto_a_new_snapshot
    recording = record_page(content: "<div>Original body.</div>")

    revision = recording.revise(actor: actor, title: "Draft two")

    assert_equal "Original body.", revision.content.to_plain_text
  end

  def test_revising_the_rich_text_itself_is_not_discarded
    recording = record_page(content: "<div>Original body.</div>")

    recording.revise(actor: actor, content: "<div>Edited body.</div>")

    assert_equal "Edited body.", recording.reload.recordable.content.to_plain_text
  end

  def test_an_explicit_change_wins_over_the_copied_content
    recording = record_page(content: "<div>Original body.</div>")

    recording.revise(actor: actor, title: "Draft two", content: "<div>Edited body.</div>")
    current = recording.reload.recordable

    assert_equal "Draft two", current.title
    assert_equal "Edited body.", current.content.to_plain_text
  end

  def test_each_snapshot_keeps_its_own_rich_text
    recording = record_page(content: "<div>Body one.</div>")
    recording.revise(actor: actor, content: "<div>Body two.</div>")

    bodies = recording.versions.map { |event| event.recordable.content.to_plain_text }

    assert_equal ["Body one.", "Body two."], bodies
  end

  def test_reverting_restores_that_snapshots_rich_text
    recording = record_page(content: "<div>Body one.</div>")
    original = recording.recordable
    recording.revise(actor: actor, content: "<div>Body two.</div>")

    recording.revert_to(original, actor: actor)

    assert_equal "Body one.", recording.reload.recordable.content.to_plain_text
  end

  def test_a_snapshot_without_rich_text_revises_cleanly
    recording = Recording.record(Page.new(title: "No body"), actor: actor)

    revision = recording.revise(actor: actor, title: "Still no body")

    assert_equal "Still no body", revision.title
    assert_empty revision.content.to_plain_text
  end

  private

    def record_page(content:, title: "Draft")
      page = Page.new(title: title)
      page.content = content
      page.save!
      Recording.record(page, actor: actor)
    end
end
