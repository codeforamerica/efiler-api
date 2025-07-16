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

get '/' do
  'Hello world!'
end

get '/efile' do

  client = Aws::SecretsManager::Client.new(
    region: 'us-east-1',
    credentials: Aws::Credentials.new(ENV["AWS_ACCESS_KEY_ID"], ENV["AWS_SECRET_ACCESS_KEY"])
  )
  begin
    get_secret_value_response = client.get_secret_value(secret_id: "efiler-api-client-mef-credentials/#{api_client_name}")
  rescue StandardError => e
    # For a list of exceptions thrown, see
    # https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
    raise e
  end

  secret = JSON.parse(get_secret_value_response.secret_string)
  puts secret

  puts "doing efile"
  EfilerService.run_efiler_command("test", "submissions-status", "4414662025127ohzns0q") # a test submission id from demo
  { foo: :bar }.to_json
rescue StandardError => e
  status 500
  { exception: e.detailed_message }.to_json
end

post '/submit' do
  submission_filename = params["submission_bundle"]["filename"]
  result = Dir.mktmpdir do |dir|
    submission_path = File.join(dir, submission_filename)
    FileUtils.mv params["submission_bundle"]["tempfile"].path, submission_path
    EfilerService.run_efiler_command("test", "submit", submission_path)
  end

  doc = Nokogiri::XML(result)
  if doc.css('SubmissionReceiptList SubmissionReceiptGrp SubmissionId').text.strip == File.basename(submission_filename, ".zip")
    status 201
    { status: "transmitted", result: result }.to_json
  else
    status 400
    { status: "failed", result: result }.to_json
  end

rescue StandardError => e
    status 500
    { exception: e.message }.to_json
end

get '/submissions-status' do
  response = EfilerService.run_efiler_command("test", "submissions-status", *params[:id])
  submission_statuses = SubmissionsStatus.handle_submission_status_response(response)
  status 200
  submission_statuses.to_json
rescue StandardError => e
  status 500
  { exception: e.message }.to_json
end

get '/acks' do
  response  = EfilerService.run_efiler_command("test", "acks", *params[:id])
  acks = Acks.handle_ack_response(response)
  status 200
  acks.to_json
rescue StandardError => e
  status 500
  { exception: e.message }.to_json
end
