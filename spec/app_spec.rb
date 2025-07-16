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

  describe "POST /submit" do
    let (:response_xml) do
      <<-XML
        <SubmissionReceiptList>
          <SubmissionReceiptGrp>
            <SubmissionId>
              fake_submission_bundle
            </SubmissionReceiptList>
          </SubmissionReceiptGrp>
        </SubmissionId>
      XML
    end

    before do
      allow(EfilerService).to receive(:run_efiler_command).with("test", "submit", anything).and_return(response_xml)
      allow_any_instance_of(Sinatra::Application).to receive(:verify_client_name_and_signature).and_return(true)
    end

    it 'creates an item and returns a success message' do
      submission_id = "fake_submission_bundle"

      file = Rack::Test::UploadedFile.new("spec/fixtures/#{submission_id}.zip", 'application/zip')

      post "/submit", submission_bundle: file
      expect(last_response.status).to eq(201)
      expect(EfilerService).to have_received(:run_efiler_command).with("test", "submit", a_string_ending_with(file.original_filename))
    end
  end

  describe "GET /submissions-status/:id" do
    before do
      allow(EfilerService).to receive(:run_efiler_command).with("test", "submissions-status", '123','456').and_return({})
      allow_any_instance_of(Sinatra::Application).to receive(:verify_client_name_and_signature).and_return(true)
    end

    it 'creates an item and returns a success message' do
      get "/submissions-status?id[]=123&id[]=456"
      expect(last_response.status).to eq(200)
      expect(EfilerService).to have_received(:run_efiler_command).with("test", "submissions-status", "123", "456")
    end
  end

  describe "GET /acks/:id" do
    before do
      allow(EfilerService).to receive(:run_efiler_command).with("test", "acks", '123','456').and_return({})
      allow_any_instance_of(Sinatra::Application).to receive(:verify_client_name_and_signature).and_return(true)
    end

    it 'creates an item and returns a success message' do
      id = "789"
      get "/acks?id[]=123&id[]=456"
      expect(last_response.status).to eq(200)
      expect(EfilerService).to have_received(:run_efiler_command).with("test", "acks", '123','456')
    end
  end
end
