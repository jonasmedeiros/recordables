require "test_helper"

class AttachmentTest < RecordablesTest
  def test_an_attachment_is_carried_onto_a_new_snapshot
    recording = record_page_with_cover

    revision = recording.revise(actor: actor, title: "Draft two")

    assert_predicate revision.cover, :attached?
    assert_equal "pixel.png", revision.cover.filename.to_s
  end

  def test_the_file_itself_is_shared_not_duplicated
    recording = record_page_with_cover
    original_blob_id = recording.recordable.cover.blob.id

    recording.revise(actor: actor, title: "Draft two")
    recording.revise(actor: actor, title: "Draft three")

    assert_equal 1, ActiveStorage::Blob.count
    assert_equal 3, ActiveStorage::Attachment.count
    assert_equal original_blob_id, recording.reload.recordable.cover.blob.id
  end

  def test_purging_one_snapshots_attachment_leaves_the_others_readable
    recording = record_page_with_cover
    original = recording.recordable
    recording.revise(actor: actor, title: "Draft two")
    current = recording.reload.recordable

    current.cover.purge

    assert_predicate original.reload.cover, :attached?
    assert_equal PIXEL.bytesize, original.cover.download.bytesize
    assert_equal 1, ActiveStorage::Blob.count
  end

  def test_the_blob_is_removed_once_the_last_reference_goes
    recording = record_page_with_cover

    recording.recordable.cover.purge

    assert_equal 0, ActiveStorage::Blob.count
    assert_equal 0, ActiveStorage::Attachment.count
  end

  def test_a_snapshot_without_an_attachment_revises_cleanly
    recording = Recording.record(Page.new(title: "No cover"), actor: actor)

    revision = recording.revise(actor: actor, title: "Still no cover")

    refute_predicate revision.cover, :attached?
  end

  def test_rich_text_and_an_attachment_travel_together
    page = Page.new(title: "Both")
    page.content = "<div>Body.</div>"
    page.save!
    attach_pixel(page)
    recording = Recording.record(page, actor: actor)

    revision = recording.revise(actor: actor, title: "Both, revised")

    assert_equal "Body.", revision.content.to_plain_text
    assert_predicate revision.cover, :attached?
  end

  private

    def record_page_with_cover
      page = Page.create!(title: "Draft")
      attach_pixel(page)
      Recording.record(page, actor: actor)
    end
end
