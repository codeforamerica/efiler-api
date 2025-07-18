ENV['RACK_ENV'] = 'test'

require "spec_helper"
require "rack/test"
require './app.rb'
require './efiler_service.rb'

RSpec.describe 'app.rb' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  let(:mef_credentials) { { mef_env: "test", app_sys_id: "foo", etin: "bar", cert_base64: "baz" } }

  before do
    allow_any_instance_of(Sinatra::Application).to receive(:verify_client_name_and_signature).and_return(true)
    allow_any_instance_of(Sinatra::Application).to receive(:get_api_client_mef_credentials).and_return(mef_credentials)
  end

  describe "POST /submit" do
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
      allow(EfilerService).to receive(:run_efiler_command).and_return(response_xml)
    end

    it 'creates an item and returns a success message' do
      file = Rack::Test::UploadedFile.new("spec/fixtures/fake_submission_bundle.zip", 'application/zip')

      post "/submit", submission_bundle: file
      expect(last_response.status).to eq(201)
      expect(EfilerService).to have_received(:run_efiler_command).with(mef_credentials, "submit", a_string_ending_with(file.original_filename))
    end
  end

  describe "GET /submissions-status" do
    before do
      allow(EfilerService).to receive(:run_efiler_command).and_return({})
    end

    it 'creates an item and returns a success message' do
      get "/submissions-status?id[]=123&id[]=456"
      expect(last_response.status).to eq(200)
      expect(EfilerService).to have_received(:run_efiler_command).with(mef_credentials, "submissions-status", "123", "456")
    end
  end

  describe "GET /acks" do
    before do
      allow(EfilerService).to receive(:run_efiler_command).and_return({})
    end

    it 'creates an item and returns a success message' do
      get "/acks?id[]=123&id[]=456"
      expect(last_response.status).to eq(200)
      expect(EfilerService).to have_received(:run_efiler_command).with(mef_credentials, "acks", '123', '456')
    end
  end
end
