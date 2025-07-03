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

  describe "POST /submit/:id" do
    before do
      allow(EfilerService).to receive(:run_efiler_command).with("test", "submit", '123').and_return({})
    end

    it 'creates an item and returns a success message' do
      id = "123"

      post "/submit/#{id}"
      expect(last_response.status).to eq(201)
    end
  end

  describe "GET /submissions-status/:id" do
    before do
      allow(EfilerService).to receive(:run_efiler_command).with("test", "submissions-status", '456').and_return({})
    end

    it 'creates an item and returns a success message' do
      id = "456"

      get "/submissions-status/#{id}"
      expect(last_response.status).to eq(200)
    end
  end

  describe "GET /acks/:id" do
    before do
      allow(EfilerService).to receive(:run_efiler_command).with("test", "acks", '789').and_return({})
    end

    it 'creates an item and returns a success message' do
      id = "789"

      get "/acks/#{id}"
      expect(last_response.status).to eq(200)
    end
  end
end
