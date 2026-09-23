require "test_helper"

class RepointOnReviseTest < RecordablesTest
  def test_revise_repoints_the_named_association_to_the_new_row
    recording = Recording.record(Board.new(title: "First"), actor: actor)
    board = recording.recordable
    card = Card.create!(board_id: board.id, name: "todo")

    revised = board.revise(actor: actor, title: "Second")

    assert_equal revised.id, card.reload.board_id
  end

  def test_copy_content_to_does_not_raise_the_uncopyable_association_guard
    recording = Recording.record(Board.new(title: "First"), actor: actor)
    board = recording.recordable
    Card.create!(board_id: board.id, name: "todo")

    revised = board.revise(actor: actor, title: "Second")

    assert_equal "Second", revised.title
  end

  def test_revise_updates_the_associations_updated_at_since_update_all_skips_touch
    recording = Recording.record(Board.new(title: "First"), actor: actor)
    board = recording.recordable
    card = Card.create!(board_id: board.id, name: "todo")
    original_updated_at = card.updated_at

    travel_helper_sleep
    board.revise(actor: actor, title: "Second")

    assert_operator card.reload.updated_at, :>, original_updated_at
  end

  def test_multiple_cards_all_get_repointed
    recording = Recording.record(Board.new(title: "First"), actor: actor)
    board = recording.recordable
    card_one = Card.create!(board_id: board.id, name: "todo")
    card_two = Card.create!(board_id: board.id, name: "doing")

    revised = board.revise(actor: actor, title: "Second")

    assert_equal revised.id, card_one.reload.board_id
    assert_equal revised.id, card_two.reload.board_id
  end

  def test_revise_still_moves_the_recordings_pointer
    recording = Recording.record(Board.new(title: "First"), actor: actor)
    original_id = recording.recordable_id

    board = recording.recordable
    board.revise(actor: actor, title: "Second")

    refute_equal original_id, recording.reload.recordable_id
  end

  private

    def travel_helper_sleep = sleep(0.01)
end
