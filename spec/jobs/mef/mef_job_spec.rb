require "rails_helper"

RSpec.describe Mef::MefJob do
  # SubmitJob's arguments include the base64 submission bundle, which ActiveJob would
  # otherwise write into every Enqueued/Performing/Performed line.
  it "does not log job arguments, for itself or any subclass" do
    jobs = [described_class, Mef::SubmitJob, Mef::SubmissionsStatusJob, Mef::AcksJob]

    expect(jobs.map(&:log_arguments?)).to all(be(false))
  end
end
