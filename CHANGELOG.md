# Changelog

## [Unreleased]

## [0.1.1] - 2026-11-08

- A folder given instead of a test file gets a clear message instead of "no such file".

## [0.1.0] - 2026-11-08

First public release.

- `deflake TEST_PATH[:LINE]` runs a Minitest or RSpec file many times, each in a fresh process with a new seed, and reports how often every test failed, with errors grouped by message and the seeds that reproduce them.
- Every failing test is run again on its own. A test that passes alone is reported as order-dependent, and deflake finds the tests that break it with its own bisect, for Minitest 5 and 6 and for RSpec. A failure must repeat to count, so a test that fails at random is reported as such, without culprits.
- Errors outside of any test, such as in an RSpec `after(:context)` hook, are reported too, and so are leaks of class-level hooks.
- Leak detection: every test is checked for global state it leaves behind, namely ENV, the clock (`travel_to` or `freeze_time` without `travel_back`), global variables, `Rails.cache`, `ActiveSupport::CurrentAttributes`, database rows and the ActiveJob test queue. Projects can add their own detectors.
- `--jobs N` runs test processes in parallel, each with its own `TEST_ENV_NUMBER`.
- `--timeout SECONDS` stops a test process that runs longer, for tests that hang.
- `--format json` for CI and other tools.
- Exit code 0 when every test passed and nothing leaked, 1 otherwise, 2 on usage errors, for a file without tests, or when the tests could not run. Ctrl-C stops the test processes and ends deflake as interrupted.
