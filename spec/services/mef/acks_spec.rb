require "rails_helper"

describe Mef::Acks do
  it "returns the correct status codes for different values of AcceptanceStatusTxt" do
    response = file_fixture("irs_acknowledgement.xml").read

    expect(described_class.parse_acks_response(response))
      .to contain_exactly(
        {irs_submission_id: "9999992021197yrv4rvl", status: :accepted, error_messages: []},
        {irs_submission_id: "9999992021197yrv4rab", status: :accepted, error_messages: []},
        {irs_submission_id: "9999992021197yrv4rcd", status: :rejected, error_messages: ["'DeviceId' in 'AtSubmissionCreationGrp' in 'FilingSecurityInformation' in the Return Header must have a value.", "'DeviceId' in 'AtSubmissionFilingGrp' in 'FilingSecurityInformation' in the Return Header must have a value."]},
        {irs_submission_id: "9999992021197yrv4ref", status: :rejected, error_messages: []},
        {irs_submission_id: "9999992021197yrv4rgh", status: :rejected, error_messages: []},
        {irs_submission_id: "9999992021197yrv4rij", status: :accepted, error_messages: []},
        {irs_submission_id: "9999992021197yrv4rkl", status: :failed, error_messages: []}
      )
  end
end
