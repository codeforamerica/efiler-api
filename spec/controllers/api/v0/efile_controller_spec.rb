require "rails_helper"

describe Api::V0::EfileController, type: :controller do
  let(:mef_credentials) { {mef_env: "test", app_sys_id: "foo", etin: "bar", cert_base64: "baz"} }

  before do
    allow_any_instance_of(described_class).to receive(:verify_client_name_and_signature).and_return(true)
    allow_any_instance_of(described_class).to receive(:get_api_client_mef_credentials).and_return(mef_credentials)
  end

  describe "#submit" do
    let(:response_xml) do
      <<-XML
        <SubmissionReceiptList>
          <SubmissionReceiptGrp>
            <SubmissionId>
              fake_submission_bundle
            </SubmissionId>
          </SubmissionReceiptGrp>
        </SubmissionReceiptList>
      XML
    end

    before do
      allow(MefService).to receive(:run_efiler_command).and_return(response_xml)
    end

    it "creates an item and returns a success message" do
      file = Rack::Test::UploadedFile.new("spec/fixtures/fake_submission_bundle.zip", "application/zip")

      post :submit, params: {submission_bundle: file}
      expect(response.status).to eq(201)
      expect(MefService).to have_received(:run_efiler_command).with(mef_credentials, "submit", a_string_ending_with(file.original_filename))
    end
  end

  describe "#submissions-status" do
    before do
      allow(MefService).to receive(:run_efiler_command).and_return({})
    end

    it "creates an item and returns a success message" do
      get :submissions_status, params: {id: [123, 456]}
      expect(response.status).to eq(200)
      expect(MefService).to have_received(:run_efiler_command).with(mef_credentials, "submissions-status", "123", "456")
    end
  end

  describe "GET /acks" do
    before do
      allow(MefService).to receive(:run_efiler_command).and_return({})
    end

    it "creates an item and returns a success message" do
      get :acks, params: {id: [123, 456]}
      expect(response.status).to eq(200)
      expect(MefService).to have_received(:run_efiler_command).with(mef_credentials, "acks", "123", "456")
    end
  end
end
