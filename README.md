<div align="center">

# deflake

**Find flaky tests in Minitest and RSpec and explain why they fail.**

Repeat · Isolate · Bisect · Detect leaked state

[![Gem Version](https://img.shields.io/gem/v/deflake?logo=rubygems&logoColor=white&color=cc342d)](https://rubygems.org/gems/deflake)
[![Downloads](https://img.shields.io/gem/dt/deflake?logo=rubygems&logoColor=white)](https://rubygems.org/gems/deflake)
[![CI](https://github.com/SlyDeath/ruby-deflake/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/SlyDeath/ruby-deflake/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/SlyDeath/ruby-deflake/graph/badge.svg)](https://codecov.io/gh/SlyDeath/ruby-deflake)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.3-cc342d?logo=ruby&logoColor=white)](https://www.ruby-lang.org)
[![License: MIT](https://img.shields.io/github/license/SlyDeath/ruby-deflake?color=blue)](LICENSE.txt)

</div>

A flaky test fails once in a while, someone adds a retry, and the cause stays.
deflake runs a suspicious test many times and answers three questions:

1. **How often does it fail**, and with which errors and seeds?
2. **Does it fail on its own**, or only after some other test? If the latter, which one?
3. **What global state does a test leave behind**: ENV, the clock, globals, `Rails.cache`, `Current` attributes, database rows, enqueued jobs?

## Installation

Add it to the test group of your Gemfile:

```ruby
group :test do
  gem "deflake", require: false
end
```

deflake needs Ruby 3.3 or newer and works with Minitest 5.11 or newer (6 included) and RSpec 3.3 or newer. It has no dependencies of its own.

## Usage

Run deflake from the root of your project:

```bash
bundle exec deflake test/models/user_test.rb --runs 50
bundle exec deflake spec/models/user_spec.rb:42 --runs 50 --jobs 4
bundle exec deflake test/models --runs 5
```

```
OrderTest#test_pollutes: failed 0 of 10 runs (0%)
  leaks: $polluted was changed (10 of 10 runs)
OrderTest#test_victim: failed 6 of 10 runs (60%)
  verdict: fails only after other tests (alone: failed 0 of 10 runs (0%))
  culprit: OrderTest#test_pollutes
  reproduce: PARALLEL_WORKERS=1 MT_CPU=1 ruby -Ilib -Itest test/models/order_test.rb --seed 16166
  seeds 16166, 35999, 58287, 35391, 30777, 1131:
    polluted by another test
```

What happens:

1. **The whole file runs `--runs` times** (10 by default), each time in a fresh `ruby` process with a new random seed. Running the whole file, not just one test, is what makes order-dependent failures show up.
2. **Every failing test runs again on its own.** If it still fails, the verdict is *fails on its own*, which points at time, randomness or a race inside the test. If it passes alone, the verdict is *fails only after other tests*.
3. **Order-dependent failures are bisected** down to the smallest set of tests that break the victim, shown as `culprit`. A failure counts only when it happens again with the same seed and order, so a test that fails at random gets the verdict *fails at random, not after particular tests* and no culprit.
4. **Every test is checked for leaks**: global state that differs before and after the test, teardown and transaction rollback included.

Errors outside of any test, such as a failing `before(:suite)` or `after(:context)` hook, or a process that fails while all its tests passed, are reported as *errors outside of tests*.

With `TEST_PATH:LINE` deflake still runs the whole file, but reports only the tests on that line. `TEST_PATH` may be a folder: deflake then checks every `*_test.rb` and `*_spec.rb` in it and in its subfolders one after another, leaving out `vendor` and `node_modules`, and at the end names the files to look at. System tests are slow, so for a first pass over a Rails app give it the folders that matter, such as `test/models`, rather than all of `test`.

The details, edge cases included, are in [How deflake works](docs/how-it-works.md).

### Options

| Option | Default | |
| --- | --- | --- |
| `-n`, `--runs N` | 10 | How many times to run each file |
| `-j`, `--jobs N` | 1 | How many test processes to run at once |
| `-t`, `--timeout SECONDS` | none | Stop a test process that runs longer, in whole seconds; the test it was running counts as failed |
| `-f`, `--format FORMAT` | `text` | `text` or `json` |

Exit code: 0 when every test passed and nothing leaked (or every test skipped itself), 1 otherwise, 2 on usage errors (a missing or extra `TEST_PATH`, `--runs` or `--jobs` below 1), when the file has no tests or a filter of the project leaves them all out, or when the tests could not run (deflake then shows their output). For a folder it is the highest code of its files, and 2 when it has no test files. When interrupted with Ctrl-C, deflake stops its test processes and ends as an interrupted program does, so a shell loop around it stops too.

### Parallel runs and databases

With `--jobs` several processes run at once. Each gets `TEST_ENV_NUMBER` set to `""`, `"2"`, `"3"`... like [parallel_tests](https://github.com/grosser/parallel_tests), so a Rails app can give each its own database:

```yaml
# config/database.yml
test:
  database: myapp_test<%= ENV["TEST_ENV_NUMBER"] %>
```

When processes share a database, their rows get in each other's way and the results say more about the database than about the tests, so deflake says so: it names the database when ActiveRecord connected the processes to the same one, and otherwise warns when the errors show them waiting for each other on one, such as `database is locked` from SQLite.

Every test process runs in a session of its own, without a terminal, as in CI: its input is empty and its output is not a TTY, so a test that skips itself unless `$stdin.tty?` always skips under deflake. In RSpec, deflake runs every example even when the project asks for `fail_fast`, and leaves out the profile; options in `SPEC_OPTS` that set the seed, the order, the formatters or `--fail-fast` are left out too, as deflake sets them itself.

deflake sets `PARALLEL_WORKERS=1` and `MT_CPU=1` for every test process, so neither Rails' `parallelize` nor Minitest's `parallelize_me!` runs tests at once: the order a seed gives stays the same and the leaks of one test do not show up in another. To rerun a seed by hand, set them too, as the `reproduce:` command does; without `PARALLEL_WORKERS=1` Rails gives the same seed a different order.

### Leak detectors

| Detector | Reports |
| --- | --- |
| ENV | Variables set, changed or removed |
| Clock | `Time.now` frozen or moved away from the real clock: `freeze_time`, `travel_to` or Timecop left on, Timecop's `mock_process_clock` included. Where the clock ends up counts, so a test that brings back a clock another test moved leaves nothing behind |
| Globals | Global variables assigned or changed in place (not Ruby's own, such as `$CHILD_STATUS`). Their whole content is compared, so a global holding a lot of data makes every test slower |
| Cache | New keys in `Rails.cache`, when it is a `MemoryStore` |
| Current | `ActiveSupport::CurrentAttributes` left set; attributes with a proc default are not compared. A default changed in place, such as a list inside it, is reported too |
| Rows | Rows created or deleted outside a rolled back transaction, in every database connected before the test; fixtures loaded during a test are not counted, nor fixtures a test without a transaction deletes again. The counts bypass ActiveRecord's query cache |
| Jobs | Jobs left in the ActiveJob test queue. `ActiveJob::TestHelper` empties the queue before each test that includes it, so with every test including it these reports are noise: remove the detector as shown below |

Detectors that do not apply, for example Rows in an app without ActiveRecord, stay quiet. A detector is any object with two methods: `snapshot` returns the current state, or `nil` when it does not apply, and `diff(before, after)` returns one message per leak. Add your own in `test_helper.rb` or `spec_helper.rb`:

```ruby
if ENV["DEFLAKE_OUTPUT"]
  require "deflake/leaks"

  class FeatureFlagLeaks
    def snapshot = FeatureFlags.enabled.sort
    def diff(before, after) = (after - before).map { |flag| "feature flag #{flag} left on" }
  end

  Deflake::Leaks.detectors << FeatureFlagLeaks.new
end
```

`DEFLAKE_OUTPUT` is set only in the processes deflake starts, so your regular test runs are not affected. The Rows detector counts rows in every table before and after each test; if that is too slow for a big schema, remove it the same way: `Deflake::Leaks.detectors.reject! { |detector| detector.is_a?(Deflake::Leaks::Rows) }`. The same goes for `Deflake::Leaks::Jobs`.

### JSON report

`--format json` prints one array for the whole run, with one object per test:

| Field | |
| --- | --- |
| `file`, `name`, `id` | The test |
| `verdict` | `stable`, `fails_on_its_own`, `order_dependent`, `random`, `failed` (could not run alone), `not_run` or `not_checked` |
| `runs`, `isolated_runs` | `total`, `failures`, `failure_rate` and `skipped`, for the runs of the file and the runs alone |
| `errors` | Error messages with their seeds |
| `leaks` | What the test left behind, with the number of runs |
| `culprits` | The tests that break this one, with the command that shows it |

Every field is described in [How deflake works](docs/how-it-works.md#json-report). The format may change until 1.0.

## Limitations

- deflake runs one file at a time, even when given a folder. A test broken by a test in another file shows up as failing only when the two files run together, which deflake does not do yet.
- Minitest files run as `ruby -Ilib -Itest FILE` (`lib` when there is one, and `-Ispec` too when there is a `spec` directory), RSpec files with RSpec's own defaults. A project that needs a different command is not supported yet.
- A Minitest error outside of tests is seen only in a run where every test passed: a failing test also makes the process fail.
- Leak detection sees what changed in the test process. It cannot see changes made by other processes, such as a browser in a system test.

## Development

```bash
bin/setup          # install dependencies
bundle exec rake   # run tests and RuboCop
```

To test against a specific Minitest major version:

```bash
MINITEST_VERSION="~> 6.0" bundle update minitest
MINITEST_VERSION="~> 6.0" bundle exec rake test
```

## License

MIT, see [LICENSE.txt](LICENSE.txt).
