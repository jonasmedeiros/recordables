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

The rule: **generate what's opinionated, keep what fails silently.** Permissions, controllers
and tree semantics are deliberately yours — that is why the generated files are plain Rails
you can rewrite freely.

## Caveats

- Never put a `uniqueness` validation on a recordable. Old snapshots still hold the old
  value, so the second edit would fail.
- Every edit inserts a row. Cheap for text; decide on retention before putting large uploads
  through it.
- `events.details` is a `json` column. Ruby 4 ships json 3.x, whose `JSON.parse` moved to
  keyword arguments while ActiveSupport 8.1 still calls it positionally. Pin
  `gem "json", "~> 2.7"` until that is fixed upstream.

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
