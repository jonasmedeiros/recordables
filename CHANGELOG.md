# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
