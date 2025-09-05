require "rails_helper"

describe Api::V0::EfileController, type: :controller do
  let(:api_client_name) { "api_client" }
  let(:api_request_id) { "fake-uuid" }
  let(:mef_credentials) { {mef_env: "test", app_sys_id: "foo", etin: "bar", cert_base64: "baz"} }

  before do
    allow_any_instance_of(described_class).to receive(:verify_client_name_and_signature).and_return(true)
    allow_any_instance_of(described_class).to receive(:api_client_name).and_return(api_client_name)
    allow_any_instance_of(described_class).to receive(:api_request_id).and_return(api_request_id)
    allow(MefService).to receive(:get_mef_credentials).and_return(mef_credentials)
  end

  after do
    stub_request(:post, webhook_url).with(body: expected_webhook_request_body)
    clear_performed_jobs
    perform_enqueued_jobs(only: WebhookCallbackJob)
    assert_performed_jobs 1
  end

  describe "#submit" do
    let(:webhook_url) { "https://example.com/submission_webhook" }
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

      let(:expected_webhook_request_body) do
        {status: "transmitted", result: response_xml, api_request_id: api_request_id}.to_json
      end

      it "calls mef service with the correct arguments and returns created status" do
        post :submit, params: {submission_bundle: submission_file, webhook_url: webhook_url}
        expect(response.status).to eq(200)

        perform_enqueued_jobs(only: Mef::SubmitJob)
        assert_performed_jobs 1
        expect(MefService).to have_received(:run_efiler_command)
          .with(mef_credentials, "submit", a_string_ending_with(submission_file.original_filename))
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

      let(:expected_webhook_request_body) do
        {status: "failed", result: response_xml, api_request_id: api_request_id}.to_json
      end

      it "calls mef service with the correct arguments and returns a failure message" do
        post :submit, params: {submission_bundle: submission_file, webhook_url: webhook_url}
        expect(response.status).to eq(200)

        perform_enqueued_jobs(only: Mef::SubmitJob)
        assert_performed_jobs 1
        expect(MefService).to have_received(:run_efiler_command)
          .with(mef_credentials, "submit", a_string_ending_with(submission_file.original_filename))
      end
    end
  end

  describe "#submissions-status" do
    let(:webhook_url) { "https://example.com/submissions_status_webhook" }
    let(:parsed_submissions_status) { "beep" }
    let(:expected_webhook_request_body) do
      {result: parsed_submissions_status, api_request_id: api_request_id}.to_json
    end

    before do
      allow(MefService).to receive(:run_efiler_command).and_return({})
      allow(Mef::SubmissionsStatus).to receive(:parse_submissions_status_response).and_return(parsed_submissions_status)
    end

    it "calls mef service with the correct arguments and returns a success message" do
      get :submissions_status, params: {id: [123, 456], webhook_url: webhook_url}
      expect(response.status).to eq(200)

      perform_enqueued_jobs(only: Mef::SubmissionsStatusJob)
      assert_performed_jobs 1
      expect(MefService).to have_received(:run_efiler_command).with(mef_credentials, "submissions-status", "123", "456")
    end
  end

  describe "#acks" do
    let(:webhook_url) { "https://example.com/acks_webhook" }
    let(:parsed_acks) { "boop" }
    let(:expected_webhook_request_body) do
      {result: parsed_acks, api_request_id: api_request_id}.to_json
    end

    before do
      allow(MefService).to receive(:run_efiler_command).and_return({})
      allow(Mef::Acks).to receive(:parse_acks_response).and_return(parsed_acks)
    end

    it "calls mef service with the correct arguments and returns a success message" do
      get :acks, params: {id: [123, 456], webhook_url: webhook_url}
      expect(response.status).to eq(200)

      perform_enqueued_jobs(only: Mef::AcksJob)
      assert_performed_jobs 1
      expect(MefService).to have_received(:run_efiler_command).with(mef_credentials, "acks", "123", "456")
    end
  end
end
