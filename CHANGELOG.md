# Changelog

## [0.2.2] - 2026-11-11

### Added

- With `--jobs`, deflake warns when test processes share a database, and names it.

### Fixed

- Rails tests that count SQL queries, such as `assert_no_queries` around cached fixtures, no longer fail under deflake.
- A test that fails at random on its own is no longer given a false culprit.
- RSpec: a bisect no longer runs examples that a file brings in from another one with `require_relative`.

## [0.2.1] - 2026-11-09

### Added

- Progress for a folder: `== FILE (3 of 40)` in the text report, `deflake: checking FILE (3 of 40)` on stderr with `--format json`.
- A file of a folder that could not run is in the JSON report too, with the verdict `not_checked`.

### Changed

- `vendor` and `node_modules` are left out when a folder is searched for tests.
- The summary lists one file per line, and a file whose tests all skipped themselves is named.

### Fixed

- A folder piped into `head` no longer ends with "unexpected error": deflake stops when the reader of the report is gone.
- After Ctrl-C the summary of a folder still lists the files checked so far, and the JSON report has their tests.
- A folder whose name ends in `:N` is taken as that folder, not as line N.

## [0.2.0] - 2026-11-09

### Added

- `TEST_PATH` may be a folder: every `*_test.rb` and `*_spec.rb` in it and its subfolders is checked, one file after another, with one report and a list of the files to look at. No more shell loops over files.
- The JSON report has the `file` of every test.

## [0.1.1] - 2026-11-08

### Fixed

- A folder given instead of a test file gets a clear message instead of "no such file".

## [0.1.0] - 2026-11-08

First public release.

### Added

- `deflake TEST_PATH[:LINE]` runs a Minitest or RSpec file many times, each in a fresh process with a new seed, and reports how often every test failed, with errors grouped by message and the seeds that reproduce them.
- Every failing test is run again on its own. A test that passes alone is reported as order-dependent, and deflake finds the tests that break it with its own bisect, for Minitest 5 and 6 and for RSpec. A failure must repeat to count, so a test that fails at random is reported as such, without culprits.
- Errors outside of any test, such as in an RSpec `after(:context)` hook, are reported too, and so are leaks of class-level hooks.
- Leak detection: every test is checked for global state it leaves behind, namely ENV, the clock (`travel_to` or `freeze_time` without `travel_back`), global variables, `Rails.cache`, `ActiveSupport::CurrentAttributes`, database rows and the ActiveJob test queue. Projects can add their own detectors.
- `--jobs N` runs test processes in parallel, each with its own `TEST_ENV_NUMBER`.
- `--timeout SECONDS` stops a test process that runs longer, for tests that hang.
- `--format json` for CI and other tools.
- Exit code 0 when every test passed and nothing leaked, 1 otherwise, 2 on usage errors, for a file without tests, or when the tests could not run. Ctrl-C stops the test processes and ends deflake as interrupted.

[0.2.2]: https://github.com/SlyDeath/ruby-deflake/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/SlyDeath/ruby-deflake/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/SlyDeath/ruby-deflake/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/SlyDeath/ruby-deflake/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/SlyDeath/ruby-deflake/releases/tag/v0.1.0
