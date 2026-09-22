# Contributing

Thanks for considering a contribution.

## Running the tests

```bash
bin/setup      # or: bundle install
bundle exec rake test
```

The suite runs against SQLite in memory and boots no Rails app, so it is fast. Generator
behaviour is exercised by generating into a temporary directory.

## What this gem will and will not take on

The scope is deliberately narrow, and pull requests are judged against it:

**In scope** — anything generic, subtle, and *silent when it goes wrong*. Snapshot
copy-forward is the clearest example: it fails without an exception, so it belongs in the
library where one fix reaches everybody.

**Out of scope** — anything opinionated about your domain: permissions, controllers,
routes, tree semantics, retention policies. Those belong in generated code you own and
edit. A pull request that moves app-shaped decisions into the gem will be declined, however
useful it is in one application — the generators exist precisely so that code can live in
your app instead.

If you are unsure which side of that line an idea falls on, open an issue first and we can
work it out before you write anything.

## Pull requests

- Add a test. A change with no test will not be merged.
- Update `CHANGELOG.md` under "Unreleased".
- Keep the diff focused; one idea per pull request.
