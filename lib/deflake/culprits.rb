# frozen_string_literal: true

module Deflake
  # Tests that make another test fail when they run before it, and a command
  # that shows the failure. ids is empty when bisect could not reproduce the failure,
  # or when the test failed with that seed with no other test before it (alone)
  Culprits = Data.define(:ids, :command, :names, :alone, :hidden, :group_wide) do
    # names: readable test names, the ids themselves by default.
    # group_wide: culprits that other tests of their group stand in for, as when the
    # state comes from a hook of the group, such as before(:context), and not from the test.
    # hidden: the failure did not happen again, but tests that cannot run by name ran in the file
    def initialize(ids:, command:, names: ids, alone: false, hidden: false, group_wide: [])
      super
    end

    def found? = ids.any?
  end
end
