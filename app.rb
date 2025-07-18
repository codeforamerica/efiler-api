require 'aws-sdk-secretsmanager'
require 'sinatra'
require 'pry-byebug'
require 'jwt'
require 'dotenv/load'
require 'nokogiri'

require_relative "efiler_service"
require_relative "acks"
require_relative "submissions_status"
require_relative "extensions/jwt_auth"

before do
  content_type 'application/json'
end

authenticate_jwt

post '/submit' do
  submission_filename = params["submission_bundle"]["filename"]
  result = Dir.mktmpdir do |dir|
    submission_path = File.join(dir, submission_filename)
    FileUtils.mv params["submission_bundle"]["tempfile"].path, submission_path
    EfilerService.run_efiler_command(get_api_client_mef_credentials, "submit", submission_path)
  end

  doc = Nokogiri::XML(result)
  if doc.css('SubmissionReceiptList SubmissionReceiptGrp SubmissionId').text.strip == File.basename(submission_filename, ".zip")
    status 201
    { status: "transmitted", result: result }.to_json
  else
    status 400
    { status: "failed", result: result }.to_json
  end

# rescue StandardError => e
#     status 500
#     { exception: e.message }.to_json
end

get '/submissions-status' do
  response = EfilerService.run_efiler_command(get_api_client_mef_credentials, "submissions-status", *params[:id])
  submission_statuses = SubmissionsStatus.handle_submission_status_response(response)
  status 200
  submission_statuses.to_json
rescue StandardError => e
  status 500
  { exception: e.message }.to_json
end

get '/acks' do
  response  = EfilerService.run_efiler_command(get_api_client_mef_credentials, "acks", *params[:id])
  acks = Acks.handle_ack_response(response)
  status 200
  acks.to_json
rescue StandardError => e
  status 500
  { exception: e.message }.to_json
end
