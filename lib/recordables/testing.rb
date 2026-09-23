module Recordables
  # Include in a test base class to get current_recordable, the fix for the
  # single most common test mistake this gem's pattern invites: calling
  # `#reload` on a recordable after an action that revised it.
  #
  #   class ActiveSupport::TestCase
  #     include Recordables::Testing
  #   end
  #
  # revise() gives a change a brand new row — a new primary key — and
  # repoints the Recording at it. The Ruby object still on hand still
  # carries the OLD primary key, so `#reload` re-fetches by that key: not
  # an error, not nil, just the exact row the action was supposed to
  # replace. A test asserting on that object after the action reads
  # whatever the row looked like BEFORE, and can pass while checking
  # nothing about what actually happened.
  #
  # Capture the Recording before the action runs — its id is the one
  # thing revise() never changes — then resolve through it afterward:
  #
  #   recording = task.recording
  #   complete_the_task(task)
  #   assert_equal "complete", current_recordable(recording).status
  module Testing
    def current_recordable(recording_or_id)
      recording = recording_or_id.is_a?(::Recording) ? recording_or_id : ::Recording.find(recording_or_id)
      recording.reload.recordable
    end
  end
end
