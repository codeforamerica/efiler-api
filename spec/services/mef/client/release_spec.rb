require "rails_helper"

describe Mef::Client::Release do
  describe ".for" do
    it "moves ATS to the processing year 2027 release on its ATS cutover date" do
      expect(described_class.for("test", on: Date.new(2026, 10, 12))).to eq(Mef::Client::Releases::ProcessingYear2026)
      expect(described_class.for("test", on: Date.new(2026, 10, 13))).to eq(Mef::Client::Releases::ProcessingYear2027)
    end

    it "keeps production on the processing year 2026 release after ATS has moved, until production's own cutover" do
      expect(described_class.for("prod", on: Date.new(2026, 12, 31))).to eq(Mef::Client::Releases::ProcessingYear2026)
      expect(described_class.for("prod", on: Date.new(2027, 1, 1))).to eq(Mef::Client::Releases::ProcessingYear2027)
    end
  end
end
