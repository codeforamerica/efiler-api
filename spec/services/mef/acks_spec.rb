require "rails_helper"

describe Mef::Acks do
  it "returns the correct status codes for different values of AcceptanceStatusTxt" do
    response = file_fixture("irs_acknowledgement.xml").read

    expect(described_class.parse_acks_response(response))
      .to contain_exactly(
        {irs_submission_id: "9999992021197yrv4rvl", status: :accepted, errors: []},
        {irs_submission_id: "9999992021197yrv4rab", status: :accepted, errors: []},
        {irs_submission_id: "9999992021197yrv4rcd", status: :rejected, errors: [{code: "IND-189", category: "Missing Data", severity: "Reject and Stop", message: "'DeviceId' in 'AtSubmissionCreationGrp' in 'FilingSecurityInformation' in the Return Header must have a value.", field_value: nil, xpath: "/efile:Return/efile:ReturnHeader", document_id: "NA"}, {code: "IND-190", category: "Missing Data", severity: "Reject and Stop", message: "'DeviceId' in 'AtSubmissionFilingGrp' in 'FilingSecurityInformation' in the Return Header must have a value.", field_value: "142111111", xpath: "/efile:Return/efile:ReturnHeader", document_id: "NA"}]},
        {irs_submission_id: "9999992021197yrv4ref", status: :rejected, errors: [{code: "IND-189", category: "Missing Data", severity: "Reject and Stop", message: "ack error 1", field_value: nil, xpath: "/efile:Return/efile:ReturnHeader", document_id: "NA"}]},
        {irs_submission_id: "9999992021197yrv4rgh", status: :rejected, errors: []},
        {irs_submission_id: "9999992021197yrv4rij", status: :accepted, errors: []},
        {irs_submission_id: "9999992021197yrv4rkl", status: :failed, errors: []}
      )
  end
end
