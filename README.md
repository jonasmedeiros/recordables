# recordables

[![Gem Version](https://badge.fury.io/rb/recordables.svg)](https://rubygems.org/gems/recordables)
[![CI](https://github.com/jonasmedeiros/recordables/actions/workflows/ci.yml/badge.svg)](https://github.com/jonasmedeiros/recordables/actions/workflows/ci.yml)

Versioned, immutable content for Rails. Every edit writes a new snapshot instead of
overwriting a row, so document history, "restore this version", and a single activity feed
across every content type all come from the same three tables.

Built on Rails' own `delegated_type`.

## The idea

A blog post is normally one row that you `UPDATE`. The old text is gone, and nothing in the
database knows a post and a message are the same *kind* of thing. This splits it in three:

```
recording  ──points at──▶  recordable     the content (Article, Note, Comment)
    │
    └──has many──▶  events                every change, and which snapshot was
                                          current when it happened
```

- **`recordings`** — the spine. Foreign keys, status, position. No text columns, so it stays
  cheap to index and paginate however large it grows.
- **recordables** — the content. Immutable: an edit inserts a row, so none of them carry
  `updated_at`.
- **`events`** — append-only, and the reason history and the activity feed are the same data.

## Getting started

```ruby
gem "recordables"
```

```bash
bin/rails generate recordables:install
bin/rails generate recordables:bucket Project name:string
bin/rails generate recordables:type Article title:string
bin/rails db:migrate
```

Models read the way Rails reads:

```ruby
class Recording < ApplicationRecord
  records :recordable, types: Recordable::TYPES
end

class Article < ApplicationRecord
  recordable
end
```

## Versioning a document

```ruby
doc = Recording.record(Article.new(title: "Spec v1"), actor: current_user, bucket: bucket)

doc.revise(actor: current_user, title: "Spec v2")
doc.revise(actor: current_user, title: "Spec v3")

doc.versions                      # every snapshot, with who and when
doc.recordable_at(2.days.ago)     # what it said then
doc.revert_to(first_snapshot, actor: current_user)
```

Three edits leave one recording and three snapshots. Restoring is a single foreign-key
update — nothing is deleted, and the revert is itself recorded:

```
v1  created   by Jonas  Spec v1
v2  updated   by Jonas  Spec v2
v3  updated   by Jonas  Spec v3
```

## One feed across every type

```ruby
Event.newest_first.limit(50)
bucket.timeline
```

Adding a content type costs nothing here — generate it and it appears. No new query, no new
branch in the feed code.

## Rich text and attachments

This is the part worth having a library for. `attributes` only carries columns, so a naive
snapshot copy drops ActionText bodies and Active Storage files **without raising**. You would
ship it and find out months later that every edited document lost its images.

`copy_content_to` finds them by reflection and carries them across. Files are shared rather
than duplicated — four versions of a document with a cover image produce four attachment rows
and one blob, and Rails reference-counts blobs, so purging one version leaves the others
readable.

## It refuses rather than lose data

A snapshot cannot carry ordinary `has_many` / `has_one` associations, so `revise` raises
instead of quietly dropping them:

```
Article owns notes, which a new snapshot cannot carry.
Model these as child recordings, or override #copy_content_to.
```

Children modelled the intended way — as child *recordings* — hang off the recording rather
than the snapshot, so revising content never touches them.

## What is generated, and what the gem keeps

| | Where it lives |
|---|---|
| Migrations, `Recording`, `Event`, `Bucket`, the concerns, each content type | **Generated into your app.** You own and edit these; the gem never touches them again |
| `records` / `recordable` macros, `revise`, `revert_to`, `versions`, `recordable_at`, `copy_content_to` and its guard | **Kept in the gem** |
| `trashable`, `recordable_belongs_to`, `immutable`, `has_children`, `repoint_on_revise`, `nested_recordable_attributes_for`, `Recordables::Testing` | **Kept in the gem** — all opt-in, none of it changes behavior for a model that doesn't call it |

The rule: **generate what's opinionated, keep what fails silently.** Permissions, controllers
and tree semantics are deliberately yours — that is why the generated files are plain Rails
you can rewrite freely.

## Trashing, and the belongs_to trap

`recordable` alone doesn't give you soft-delete — a "trashed" Recording still leaves its
row visible to every plain query, since `trash!` only changes the *Recording's* status,
nothing about the row itself. `trashable` closes that gap:

```ruby
class Article < ApplicationRecord
  recordable
  trashable
end

article.recording.trash!(actor: current_user)

Article.count            # doesn't see it
Article.with_trashed.count  # does
```

The one thing this doesn't fix by itself is `belongs_to`. Rails' association reader builds
its own `WHERE id = ...` directly against the target class, bypassing `trashable`'s
`default_scope` entirely — so a plain `belongs_to :article` on some other model silently
returns the stale, trashed-or-superseded row instead of nil or the current version. This is
the sharpest edge in the whole pattern, and it fails silently: nothing raises, the wrong data
just quietly comes back. `recordable_belongs_to` is the fix:

```ruby
class Comment < ApplicationRecord
  recordable_belongs_to :article
end
```

It resolves through the append-only `Event` log instead of the raw foreign key — an event's
`recordable_id` is set once, when that event happened, and never rewritten, so it still names
the right lineage no matter how many times the target's been revised since.

## Enforcing immutability

Nothing about `recordable` stops a `template.update!(name: "x")` from working even after
you've adopted `revise()` everywhere else — it just silently mutates the row in place. No new
snapshot, no history entry, no way to revert, and anything reading `cache_version` or
`updated_at` through the Recording never sees the change. `immutable` turns that into a hard
failure instead of a silent one:

```ruby
class Article < ApplicationRecord
  recordable
  immutable
end

article.update!(title: "x")   # raises Recordables::ImmutableRecordable
article.update_column(:title, "x")  # raises too — callbacks alone don't catch this
Article.update_all(title: "x")      # raises at the class level
```

`record`/`revise` are unaffected — they only ever save a fresh, not-yet-persisted instance,
never a second write against a row that's already there.

## Children: a real has_many, or a child Recording?

Two different shapes both look like "this recordable owns other rows," and mixing them up
either loses data or silently orphans it.

**A child Recording** (`has_children`) is for content that's genuinely part of the parent's
lineage — a `Task` under its `Routine`, a line item under an order. A plain foreign key would
orphan every child the moment the parent is revised (a new row, a new id) — the fix is
letting the *child's own Recording* carry the parent link instead, via `parent_id`, which
survives revisions because a Recording's own id never changes:

```ruby
class Routine < ApplicationRecord
  recordable
  has_children :tasks
end

routine.tasks                              # current children, ordered
routine.add_task(actor: current_user, name: "Stretch")
```

**A real `has_many`** (`repoint_on_revise`) is for join rows that point *at* a recordable by a
plain foreign key, and need to follow a revision rather than travel with the child-Recording
tree — a tagging table, an assignment. `revise()` alone would leave every one of those rows
FK'd to the old, now-superseded id. `repoint_on_revise` moves them to the new one in the same
transaction, and also defines `copy_content_to` as a no-op — these associations were never
content to *copy forward*, they're pointers *at* the row, so the default
`UncopyableAssociation` guard doesn't apply here:

```ruby
class RoutineTemplate < ApplicationRecord
  recordable
  repoint_on_revise :routine_template_people
end
```

If in doubt: does the association exist to organize the recordable's own content (child
Recording), or does something external point at it (repoint_on_revise)?

## Nested forms

`accepts_nested_attributes_for` can't work on a `has_children` association — it writes
straight to association rows at `assign_attributes` time, but a new child needs its own
Recording, which needs the parent to already be saved or revised. `nested_recordable_attributes_for`
does the same job (a form posts an array of `{id:, ...fields, _destroy:}` hashes) through
`revise()`/`trash!` instead of a raw write:

```ruby
class Routine < ApplicationRecord
  recordable
  has_children :tasks
  nested_recordable_attributes_for :tasks
end
```

```erb
<%= form_with model: @routine do |f| %>
  <%= f.fields_for :tasks, @routine.tasks_for_form do |task_fields| %>
    ...
  <% end %>
<% end %>
```

Two-phase, matching how a controller/interactor already has to split "assign" from "save"
here: `tasks_attributes=` stores the submitted rows without writing anything, then
`apply_tasks_attributes!(actor:)` — called once the routine itself has a current Recording —
creates, revises, or trashes each one.

## Testing

The most common mistake this whole pattern invites: calling `#reload` on a recordable after
an action that revised it.

```ruby
task = create_a_task
complete_the_task(task)
task.reload.status   # => "initial", not "complete"
```

`revise()` gives an edit a brand new row — a new primary key — and repoints the Recording at
it. `task` still holds the *old* primary key, so `#reload` re-fetches by that key: not an
error, not nil, just exactly the row the action was supposed to replace. A test asserting on
`task` after the action silently checks what things looked like *before*.

```ruby
class ActiveSupport::TestCase
  include Recordables::Testing
end
```

```ruby
recording = task.recording      # capture before — a Recording's id never changes
complete_the_task(task)
assert_equal "complete", current_recordable(recording).status
```

## Adopting recordable on an existing table

Once a model has `trashable`, its `default_scope` hides any row with no active
Recording — which, the moment you first add `trashable`, is every existing row. The
migration that's supposed to create each row's first Recording has to bypass that scope to
see them at all:

```bash
bin/rails generate recordables:backfill RoutineTemplate
```

```ruby
# generated: db/migrate/..._backfill_routine_templates_recordings.rb
RoutineTemplate.with_trashed.find_each do |routine_template|
  Recording.record(routine_template, actor: routine_template.actor, created_at: routine_template.created_at)
end
```

Miss `.with_trashed` here — plain `find_each` — and the migration doesn't error. It "succeeds"
in milliseconds, having created zero Recordings, and nothing about that looks wrong until
something downstream (a query, a destroy cascade) turns up rows with no history at all.

## Caveats

- Never put a `uniqueness` validation on a recordable. Old snapshots still hold the old
  value, so the second edit would fail.
- Every edit inserts a row. Cheap for text; decide on retention before putting large uploads
  through it.
- `events.details` is a `json` column. Ruby 4 ships json 3.x, whose `JSON.parse` moved to
  keyword arguments while ActiveSupport 8.1 still calls it positionally. Pin
  `gem "json", "~> 2.7"` until that is fixed upstream.
- On a `trashable` type, `Model.delete_all` / `Model.destroy_all` raise rather than run.
  Under `default_scope` they'd only ever touch rows with an active Recording — anything
  already trashed survives, silently — which is exactly backwards from what a test
  teardown's `delete_all` or a `DatabaseCleaner` truncation strategy expects. Call
  `Model.with_trashed.delete_all` if you mean it, or scope down first
  (`Model.where(...).delete_all`) if you meant only some of the active rows.

## Development

```bash
bundle install
bundle exec rake test
```

The suite boots a small Rails application in `test/dummy`, so Action Text, Active Storage
and the generators are exercised for real rather than stubbed. 41 tests cover the snapshot
lifecycle, rich text and attachment copy-forward, blob sharing, the uncopyable-association
guard, and all three generators.

## License

MIT.
