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

1. **The whole file runs `--runs` times** (10 by default), every time in a fresh `ruby` process with a new random seed. Running the whole file, not just one test, is what makes order-dependent failures show up. A test that takes its process down (`exit`, a crash, a signal) counts as failed in that run.
2. **Every test that failed runs again on its own**, as many times. The verdict is *fails on its own* if it still fails, which points at time, randomness or a race inside the test, or *fails only after other tests* if it does not, or if it skips itself every time it runs alone. When it cannot run alone at all, as with errors outside of tests or a file that breaks before any test whenever one test runs on its own, the verdict is *failed, could not run it alone*. The errors of the runs alone are shown too when the runs of the file did not have them.
3. **Order-dependent failures are bisected** with one of the failing seeds, down to a smallest set of tests that break the victim; when two tests break it independently, one set is named. deflake has the test framework run just those tests in the recorded order, so hooks around a whole class still run, and watches only the victim, so other failing tests do not get in the way. A failure counts only when it happens twice in a row, and the set found must break the victim again at the end, so a test that fails at random gets no culprits: when the failure does not happen again with the same seed and order, the verdict is *fails at random, not after particular tests*, with the command that runs that seed. Tests in a class without a name cannot be put in an order, so when the file has some and the failure does not happen again without them, the verdict stays *fails only after other tests*, and deflake says it could not look among them. When the victim fails with that seed with no test before it, the verdict is *fails on its own*, with the command that shows it. Up to three failing seeds are tried, the first seed of every error first. A test that fails on its own is bisected too when the runs of the file have an error it never had alone; errors that differ only in numbers, as those of a test that fails at random do, count as the same error. A culprit that two other tests of its group replace, because the state comes from a hook of the group such as `before(:context)` or `before_all`, is named as such. A victim stopped by `--timeout` does not count as failing in a bisect, as fewer tests before it would not reach the limit. This works on Minitest 5 and 6 alike, `Minitest::Spec` included, and on RSpec, which keeps the relative order of any subset of examples for a seed.
4. **Every test is checked for leaks**, tests that skip themselves included: a snapshot of global state before the test, setup included, and after it, teardown, transaction rollback and whatever Rails does around a test (such as the executor clearing `Current`) included. Whatever changed is reported. So is what a whole Minitest class or top-level RSpec group leaves behind beyond the leaks of its tests, such as the state a `before_all` or `before(:context)` hook sets up and never puts back: it shows up under *errors outside of tests*.

A process that fails while every test in it passed is reported as *errors outside of tests*, with the end of its output. An error RSpec reports outside of examples, such as in an `after(:context)` hook, is reported with its class and message, even when an example failed in the same run. So is a run that breaks before its first test, such as a `before(:suite)` hook that fails now and then: the other runs still count. A failure deflake cannot run again by name, such as a class-level hook (minitest-hooks' `before_all`) that reports its error as a result, shows up there too. Only when no run gets to a test does deflake give up with exit code 2, and say how the test process ended, for example that it timed out.

With `TEST_PATH:LINE` deflake still runs the whole file, but reports only the tests on that line, and errors outside of tests, which may be what stopped them. In Minitest that is the test declared closest above the line, whatever its style: `def test_...`, Rails' `test "..."`, `it "..."` or a macro of the project that defines a test; a line in a test of a class without a name is refused, as such a test cannot run alone. In RSpec it is what `rspec TEST_PATH:LINE` runs: the example on that line, or every example of a `describe` or `context` on that line, found with a dry run that runs no example and no hook. A test on the line that never started in any run, for example because an earlier test always takes the process down or a filter of the file leaves it out, makes deflake say so and exit with 1; the JSON report lists it with the verdict `not_run`.

`TEST_PATH` may be a folder: deflake then finds every `*_test.rb` and `*_spec.rb` in it and in its subfolders, leaving out `vendor` and `node_modules`, and checks them one after another, each as if it were given on its own. The report of each file starts with `== FILE (3 of 40)`; with `--format json` that line goes to stderr as `deflake: checking FILE (3 of 40)`. A file that cannot run is reported and the others are still checked. At the end deflake names the files with failing or leaking tests and those it could not check, also after Ctrl-C, for the files checked so far. When the reader of the report stops early, as `head` does, deflake stops too. System tests are slow, so for a first pass over a Rails app give it the folders that matter, such as `test/models`, rather than all of `test`.

Files ending in `_spec.rb` go to RSpec, unless they mention Minitest (a `minitest_helper` counts, and so do expectations such as `_(x).must_equal`) and neither RSpec nor `rails_helper`: those are `Minitest::Spec` files.

A Minitest test is known by its class and method, `UserTest#test_name`. When two classes have the same name, as two `describe` blocks with the same description do, the second one's tests are `Name (2)#test_...`. A failing test in a class without a name, made with `Class.new` and never given one, cannot be run again by name: its failure shows up under *errors outside of tests*. A test a file brings in from another one with `require_relative` belongs to that other file, not to the line of the `require_relative`.

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
| Globals | Global variables assigned or changed in place (not Ruby's own, such as `$CHILD_STATUS`). The whole content of what they hold is compared, as `Marshal` dumps it. An object `Marshal` cannot dump, such as a client holding a `Mutex` or a connection, counts by identity, so what it sets up inside on first use is not a leak; arrays, hashes, structs, sets and `StringIO` are still compared part by part, and queues by their size and whether they are closed. The order of a hash or a set does not matter. A value of any kind works, even a mock without Kernel's methods. `Marshal` dumps every global twice per test, so a global holding a lot of data makes every test slower |
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

`--format json` prints one array for the whole run, with one object per test that ran or leaked (a test that skipped itself in every run and leaked nothing is left out, as in the text report) with `file`, `name`, `id`, `verdict` (`stable`, `failed`, `fails_on_its_own`, `order_dependent`, `random`, `not_run` for a test on the line that never started, or `not_checked` for a file of a folder that could not run, with its error under `errors`; `failed` means a test could not run alone), `runs` and `isolated_runs` counts (`isolated_runs` is `null` when the test never failed or could not run alone, as errors outside of tests cannot) (`total`, `failures`, `failure_rate` and `skipped`: `total` leaves out the runs where the test skipped itself), `errors` with their seeds, `leaks` (with `runs`, counting the runs where the test skipped itself too) and `culprits` (`ids`, `names`, `command`, `alone` when the test fails with no test before it, `hidden` when tests in a class without a name may be to blame, and `group_wide`). The format may change until 1.0.

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
