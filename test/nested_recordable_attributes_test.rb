require "test_helper"

class NestedRecordableAttributesTest < RecordablesTest
  def test_attributes_setter_stores_pending_rows_without_writing_anything
    playlist = Recording.record(Playlist.new(title: "Roadtrip"), actor: actor).recordable

    playlist.tracks_attributes = [{ "title" => "Song One" }]

    assert_equal 0, playlist.tracks.count
    assert_equal [{ "title" => "Song One" }], playlist.pending_tracks_attributes
  end

  def test_apply_creates_a_new_child_for_a_row_with_no_id
    playlist = Recording.record(Playlist.new(title: "Roadtrip"), actor: actor).recordable
    playlist.tracks_attributes = [{ "title" => "Song One" }]

    playlist.apply_tracks_attributes!(actor: actor)

    assert_equal ["Song One"], playlist.tracks.map(&:title)
  end

  def test_apply_passes_recording_attributes_through_to_the_new_childs_recording
    playlist = Recording.record(Playlist.new(title: "Roadtrip"), actor: actor).recordable
    playlist.tracks_attributes = [{ "title" => "Song One" }]

    playlist.apply_tracks_attributes!(actor: actor)

    track_recording = Recording.where(recordable_type: "Track").where(parent_id: playlist.recording.id).first
    assert_equal 100, track_recording.position
  end

  def test_apply_revises_an_existing_child_whose_id_is_present
    playlist = Recording.record(Playlist.new(title: "Roadtrip"), actor: actor).recordable
    playlist.add_track(actor: actor, title: "Original")
    existing = playlist.tracks.first

    playlist.tracks_attributes = [{ "id" => existing.id, "title" => "Renamed" }]
    playlist.apply_tracks_attributes!(actor: actor)

    assert_equal ["Renamed"], playlist.tracks.map(&:title)
    assert_equal 1, playlist.tracks.count
  end

  def test_apply_trashes_a_child_marked_for_destroy
    playlist = Recording.record(Playlist.new(title: "Roadtrip"), actor: actor).recordable
    playlist.add_track(actor: actor, title: "Original")
    existing = playlist.tracks.first

    playlist.tracks_attributes = [{ "id" => existing.id, "_destroy" => "1" }]
    playlist.apply_tracks_attributes!(actor: actor)

    assert_equal [], playlist.tracks.to_a
  end

  def test_apply_handles_a_mix_of_create_update_and_destroy_in_one_call
    playlist = Recording.record(Playlist.new(title: "Roadtrip"), actor: actor).recordable
    playlist.add_track(actor: actor, title: "Keep")
    playlist.add_track(actor: actor, title: "Rename")
    playlist.add_track(actor: actor, title: "Remove")
    keep, rename, remove = playlist.tracks.to_a

    playlist.tracks_attributes = [
      { "id" => keep.id },
      { "id" => rename.id, "title" => "Renamed" },
      { "id" => remove.id, "_destroy" => "1" },
      { "title" => "Brand New" }
    ]
    playlist.apply_tracks_attributes!(actor: actor)

    assert_equal ["Brand New", "Keep", "Renamed"], playlist.tracks.map(&:title).sort
  end

  def test_a_row_marked_for_destroy_with_no_id_is_simply_skipped
    playlist = Recording.record(Playlist.new(title: "Roadtrip"), actor: actor).recordable

    playlist.tracks_attributes = [{ "title" => "Ghost", "_destroy" => "1" }]
    playlist.apply_tracks_attributes!(actor: actor)

    assert_equal [], playlist.tracks.to_a
  end

  def test_apply_without_a_prior_attributes_setter_call_is_a_no_op
    playlist = Recording.record(Playlist.new(title: "Roadtrip"), actor: actor).recordable
    playlist.add_track(actor: actor, title: "Untouched")

    playlist.apply_tracks_attributes!(actor: actor)

    assert_equal ["Untouched"], playlist.tracks.map(&:title)
  end

  def test_rendered_tracks_reflects_pending_rows_for_form_re_render
    playlist = Recording.record(Playlist.new(title: "Roadtrip"), actor: actor).recordable
    playlist.tracks_attributes = [{ "title" => "Typed but not saved" }]

    assert_equal ["Typed but not saved"], playlist.rendered_tracks.map(&:title)
  end

  def test_rendered_tracks_falls_back_to_persisted_children_without_a_submission
    playlist = Recording.record(Playlist.new(title: "Roadtrip"), actor: actor).recordable
    playlist.add_track(actor: actor, title: "Persisted")

    assert_equal ["Persisted"], playlist.rendered_tracks.map(&:title)
  end

  def test_build_track_appends_a_blank_row_to_rendered_tracks
    playlist = Recording.record(Playlist.new(title: "Roadtrip"), actor: actor).recordable

    playlist.build_track

    assert_equal 1, playlist.rendered_tracks.size
    refute_predicate playlist.rendered_tracks.first, :persisted?
  end
end
