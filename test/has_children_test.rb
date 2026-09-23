require "test_helper"

class HasChildrenTest < RecordablesTest
  def test_add_track_creates_a_recording_parented_to_the_playlists_recording
    playlist_recording = Recording.record(Playlist.new(title: "Roadtrip"), actor: actor)
    playlist = playlist_recording.recordable

    track_recording = playlist.add_track(actor: actor, title: "Song One")

    assert_equal playlist_recording.id, track_recording.parent_id
  end

  def test_tracks_lists_only_children_of_this_playlist
    playlist = Recording.record(Playlist.new(title: "Roadtrip"), actor: actor).recordable
    other_playlist = Recording.record(Playlist.new(title: "Workout"), actor: actor).recordable

    playlist.add_track(actor: actor, title: "Song One")
    other_playlist.add_track(actor: actor, title: "Song Two")

    assert_equal ["Song One"], playlist.tracks.map(&:title)
  end

  def test_tracks_is_empty_before_the_playlist_has_a_recording
    playlist = Playlist.new(title: "Unsaved")

    assert_equal [], playlist.tracks.to_a
  end

  def test_tracks_returns_multiple_children_in_position_order
    playlist = Recording.record(Playlist.new(title: "Roadtrip"), actor: actor).recordable

    playlist.add_track(actor: actor, title: "Second")
    playlist.add_track(actor: actor, title: "First")

    assert_equal 2, playlist.tracks.count
  end

  def test_a_trashed_track_no_longer_appears_among_tracks
    playlist = Recording.record(Playlist.new(title: "Roadtrip"), actor: actor).recordable
    track_recording = playlist.add_track(actor: actor, title: "Song One")

    track_recording.trash!(actor: actor)

    assert_equal [], playlist.tracks.to_a
  end
end
