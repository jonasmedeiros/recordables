# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `nested_recordable_attributes_for` accepts `recording_attributes:`, an optional proc
  called once per new child (with the parent record) to build extra attributes for that
  child's Recording. Without it, `apply_#{plural}_attributes!` creating a new child had
  no way to set anything beyond `actor:` and the child's own fields — any host app whose
  Recording has its own required columns (an `account_id` or similar tenant column is
  the common case) hit a hard `NOT NULL` failure the moment a form actually submitted a
  new child row.

## [0.2.0]

### Added

- `trashable` — `default_scope` + `with_trashed` for a recordable type whose Recording
  can be trashed, so a trashed row stops showing up in normal queries. Paired with
  `Recording.active` and `Recording#trash!`.
- `recordable_belongs_to` — a `belongs_to` replacement for a target that's `trashable`.
  Plain `belongs_to` builds its own `WHERE id = ...` directly against the target class,
  bypassing `trashable`'s `default_scope` entirely, and silently returns a stale,
  superseded row instead of the current one. Resolves through the append-only Event log
  instead, which always names the current version.
- `immutable` — raises if `update`, `update!`, `update_column(s)`, `save` (with pending
  changes), `destroy`, `delete`, or class-level `update_all` are called directly against
  a persisted recordable, instead of silently mutating a row that's supposed to be an
  immutable snapshot. `record`/`revise` are unaffected — they only ever save a fresh,
  not-yet-persisted instance.
- `has_children` — the child-Recording pattern (a Task under its Routine) as two
  generated methods per name: a read-only, ordered listing and an `add_*` that creates
  the child with its own Recording, parented to the current one.
- `nested_recordable_attributes_for` — the `accepts_nested_attributes_for` shape for a
  `has_children` association, since the real thing can't work here (it writes straight
  to association rows at `assign_attributes` time; a child needs a Recording, which
  needs the parent to be saved/revised first). Two-phase: `#{plural}_attributes=` stores
  the submitted rows, `apply_#{plural}_attributes!` creates/revises/trashes them once
  the parent has a current Recording.
- `repoint_on_revise` — for a real `has_many` pointed at a recordable type by a plain
  foreign key (not a child Recording): repoints every row at the new id `revise()`
  creates, in the same transaction, instead of leaving them FK'd to what just became
  obsolete. Also defines `copy_content_to` as a no-op, since these associations were
  never content to copy forward in the first place.
- `Recordables::Testing#current_recordable` — the fix for the most common test mistake
  this gem's pattern invites: `#reload` on a recordable after an action that revised it
  re-fetches by the object's own, now-superseded primary key, silently returning what
  the row looked like *before*. Capture the Recording first, resolve through it after.
- `recordables:backfill` generator — scaffolds the migration for adopting
  `recordable`/`trashable` on a table that already has rows. Exists because of one
  specific trap: once a model has `trashable`, a bare `Model.find_each` inside the very
  migration meant to create that model's first Recordings iterates zero rows — every
  row is invisible under a scope that hides anything without an active Recording yet,
  which at backfill time is all of them. `Model.with_trashed.find_each` fixes it, but
  the migration "succeeds" having touched nothing if it's missing, and nothing about
  that looks wrong until much later.
- `Recordable#recording` — the current Recording pointing at a snapshot
  (`recordings.last`). Previously left for every consumer to define for themselves.
- `delete_all` / `destroy_all` on a `trashable` type now raise instead of silently only
  clearing rows with an active Recording — the ambiguity that trips up a test teardown's
  `delete_all`, a `DatabaseCleaner` truncation strategy, or a rake task clearing a table,
  all expecting the table to end up actually empty. `with_trashed.delete_all` (or scoping
  down first, e.g. `Model.where(...).delete_all`) says which is meant.

## [0.1.0]

### Fixed

- `revise` silently discarded edits to rich text: changes were merged into the column
  attributes before `copy_content_to` ran, so the copy overwrote them with the previous
  body. Changes are now applied after the copy and always win.
- `recordables:install --actor` accepted any string, generating models with a broken
  `class_name:` reference (e.g. `--actor="bad name"`) that only failed at runtime, far
  from the mistake. It now validates the same way `recordables:type` and
  `recordables:bucket` already did.

### Added

- `records` and `recordable` class macros on `ActiveRecord::Base`.
- `recordables:install` generator — migration, `Recording`, `Event`, the `Recordable`
  concern, and optionally `Bucket` / `Bucketable` (`--skip-buckets` to omit).
- `recordables:type` generator — an immutable content type, registered in `Recordable::TYPES`.
- `recordables:bucket` generator — a container type, registered in `Bucketable::TYPES`.
- `revise`, `revert_to`, `versions`, `recordable_at` for snapshot versioning and history.
- `copy_content_to` carries ActionText rich text and Active Storage attachments onto a new
  snapshot, discovered by reflection rather than per-type configuration.
- `Recordables::Recordable::UncopyableAssociation` — raised instead of silently dropping
  ordinary `has_many` / `has_one` associations a snapshot cannot carry.
- A dummy Rails application under `test/dummy`, so the suite exercises Action Text,
  Active Storage and the generators against a real Rails environment.
