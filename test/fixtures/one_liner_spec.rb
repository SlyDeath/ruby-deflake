# frozen_string_literal: true

# RSpec names a one-liner only once its matcher runs, so the failing runs of
# the victim have another name than the passing ones
$one_liner_polluted = false

RSpec.describe "Polluter" do
  it("pollutes") { $one_liner_polluted = true }
end

RSpec.describe "Victim" do
  subject do
    raise "polluted" if $one_liner_polluted

    1
  end

  it { is_expected.to eq(1) }
end
