require "rails_helper"

describe Api::V0::EfileController, type: :controller do
  let(:mef_credentials) { {mef_env: "test", app_sys_id: "foo", etin: "bar", cert_base64: "baz"} }

  before do
    allow_any_instance_of(described_class).to receive(:verify_client_name_and_signature).and_return(true)
    allow_any_instance_of(described_class).to receive(:get_api_client_mef_credentials).and_return(mef_credentials)
  end

  describe "#submit" do
    let(:submission_file) { Rack::Test::UploadedFile.new("spec/fixtures/files/fake_submission_bundle.zip", "application/zip") }
    before do
      allow(MefService).to receive(:run_efiler_command).and_return(response_xml)
    end

    context "response contains matching submission ID" do
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

      it "calls mef service with the correct arguments and returns created status" do
        post :submit, params: {submission_bundle: submission_file}
        expect(MefService).to have_received(:run_efiler_command).with(mef_credentials, "submit", a_string_ending_with(submission_file.original_filename))
        expect(response.status).to eq(201)
      end
    end

    context "response does not contain matching submission ID" do
      let(:response_xml) do
        <<-XML
          <SubmissionReceiptList>
            <SubmissionReceiptGrp>
              <SubmissionId>
                fake_fake_fake
              </SubmissionId>
            </SubmissionReceiptGrp>
          </SubmissionReceiptList>
        XML
      end

      it "calls mef service with the correct arguments and returns a failure message" do
        post :submit, params: {submission_bundle: submission_file}
        expect(MefService).to have_received(:run_efiler_command).with(mef_credentials, "submit", a_string_ending_with(submission_file.original_filename))
        expect(response.status).to eq(400)
      end
    end
  end

  describe "#submissions-status" do
    before do
      allow(MefService).to receive(:run_efiler_command).and_return({})
    end

    it "calls mef service with the correct arguments and returns a success message" do
      get :submissions_status, params: {id: [123, 456]}
      expect(response.status).to eq(200)
      expect(MefService).to have_received(:run_efiler_command).with(mef_credentials, "submissions-status", "123", "456")
    end
  end

  describe "#acks" do
    before do
      allow(MefService).to receive(:run_efiler_command).and_return({})
    end

    it "calls mef service with the correct arguments and returns a success message" do
      get :acks, params: {id: [123, 456]}
      expect(response.status).to eq(200)
      expect(MefService).to have_received(:run_efiler_command).with(mef_credentials, "acks", "123", "456")
    end
  end
end
