# frozen_string_literal: true

require "test_helper"

module Deflake
  class InvestigationTest < Minitest::Test
    FIXTURES = File.expand_path("../fixtures", __dir__)

    def test_tells_stable_tests_from_ones_that_fail_on_their_own
      verdicts = investigate("sample.rb", runs: 2).to_h { |diagnosis| [diagnosis.name, diagnosis.verdict] }

      assert_equal({ "SampleTest#test_fails" => :fails_on_its_own,
                     "SampleTest#test_passes" => :stable,
                     "SampleTest#test_raises" => :fails_on_its_own }, verdicts)
    end

    # The victim fails in about half of the runs, so 20 runs miss it once in a million
    def test_finds_the_minitest_that_breaks_another_one
      victim = find(investigate("order.rb", runs: 20), "OrderTest#test_victim")

      assert_equal :order_dependent, victim.verdict
      assert_equal ["OrderTest#test_pollutes"], victim.culprits.ids
    end

    def test_finds_the_culprit_in_minitest_spec_files
      victim = find(investigate("spec_order.rb", runs: 20), "Spec order#test_0003_is the victim")

      assert_equal :order_dependent, victim.verdict
      assert_equal ["Spec order#test_0001_pollutes"], victim.culprits.ids
    end

    def test_finds_a_culprit_that_skipped_itself
      victim = find(investigate("skip_polluter.rb", runs: 20), "SkipPolluterTest#test_victim")

      assert_equal ["SkipPolluterTest#test_pollutes_then_skips"], victim.culprits.ids
    end

    def test_reruns_a_test_with_slashes_in_its_name_really_alone
      victim = find(investigate("slash.rb", runs: 20), "SlashTest#test_GET_/users/1_works")

      assert_equal :order_dependent, victim.verdict
      assert_equal ["SlashTest#test_pollutes_users"], victim.culprits.ids
    end

    def test_finds_the_example_that_breaks_another_one
      victim = find(investigate("order_spec.rb", runs: 20), "Order is the victim")

      assert_equal :order_dependent, victim.verdict
      assert_equal ["Order pollutes"], victim.culprits.names
    end

    # zsh, the default shell on macOS, makes rspec --bisect quote the example ids
    def test_leaves_other_failing_examples_out_of_the_culprits_in_any_shell
      victim = with_shell("/bin/zsh") { find(investigate("noisy_order_spec.rb", runs: 20), "Noisy is the victim") }

      assert_equal :order_dependent, victim.verdict
      assert_equal ["Noisy pollutes"], victim.culprits.names
    end

    def test_keeps_examples_with_the_same_description_apart
      diagnoses = investigate("dup_names_spec.rb", runs: 2)

      runs = diagnoses.map(&:file_runs)

      assert_equal [[2, 0], [2, 2]], runs.map { |summary| [summary.total, summary.failures] }.sort
      assert_equal %i[fails_on_its_own stable], diagnoses.map(&:verdict).sort
    end

    # Its failing runs and its passing runs have different names
    def test_follows_a_one_liner_by_its_id
      victim = find(investigate("one_liner_spec.rb", runs: 20), "Victim is expected to eq 1")

      assert_equal 20, victim.file_runs.total
      assert_equal :order_dependent, victim.verdict
      assert_equal ["Polluter pollutes"], victim.culprits.names
    end

    # Alone it skips itself every time; after the other test it fails
    def test_finds_the_culprit_of_a_test_that_skips_itself_alone
      victim = find(investigate("skip_alone.rb", runs: 20), "SkipAloneTest#test_victim")

      assert_equal :order_dependent, victim.verdict
      assert_equal 0, victim.isolated_runs.total
      assert_equal ["SkipAloneTest#test_turns_flag_on"], victim.culprits.ids
    end

    def test_reports_nothing_when_every_test_skips_itself
      assert_empty investigate("all_skipped.rb", runs: 2)
    end

    # The order goes through a file: Linux refuses an environment variable over 128 KiB
    def test_runs_tests_in_an_order_too_long_for_an_environment_variable
      ids = ["SampleTest#test_passes"] * 7000

      rows = Adapters::Minitest.run_in_order(File.join(FIXTURES, "sample.rb"), ids, seed: 1)

      assert_equal(7000, rows.count { |row| row["passed"] })
    end

    def test_finds_no_test_on_a_line_before_running_the_file
      investigation = NoRuns.new(File.join(FIXTURES, "sample.rb"), runs: 50, line: 2)

      assert_raises(Error) { investigation.call }
    end

    # Fails the test if it runs the file
    class NoRuns < Investigation
      private

      def runner(...) = raise(Minitest::Assertion, "ran the file before looking for the line")
    end

    private

    def investigate(fixture, runs:)
      Investigation.new(File.join(FIXTURES, fixture), runs: runs).call
    end

    def find(diagnoses, name)
      diagnoses.find { |diagnosis| diagnosis.name == name } or flunk "#{name} not in #{diagnoses.map(&:name)}"
    end

    def with_shell(shell, &)
      with_env("SHELL" => shell, &)
    end

    def with_env(values)
      old = values.keys.to_h { |name| [name, ENV.fetch(name, nil)] }
      ENV.update(values)
      yield
    ensure
      ENV.update(old)
    end
  end
end
