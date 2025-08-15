require "rails_helper"

describe Mef::Acks do
  it "returns the correct status codes for different values of AcceptanceStatusTxt" do
    response = file_fixture("irs_acknowledgement.xml").read

    expect(described_class.handle_ack_response(response))
      .to match_array(
            [
              ["9999992021197yrv4rvl", :accepted],
              ["9999992021197yrv4rab", :accepted],
              ["9999992021197yrv4rcd", :rejected],
              ["9999992021197yrv4ref", :rejected],
              ["9999992021197yrv4rgh", :rejected],
              ["9999992021197yrv4rij", :accepted_but_imperfect],
              ["9999992021197yrv4rkl", :failed],
            ]
          )
  end
end