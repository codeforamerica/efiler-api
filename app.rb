if %w[development test].include? ENV["RACK_ENV"]
  require "dotenv"
  Dotenv.load(overwrite: true)
end

require "aws-sdk-secretsmanager"
require "sinatra"
require "sinatra/namespace"
require "jwt"
require "nokogiri"

require_relative "efiler_service"
require_relative "acks"
require_relative "submissions_status"
require_relative "extensions/efiler_api_client_auth"

before do
  content_type "application/json"
end

authenticate_jwt("/api/*")

get "/health" do
  :ok
end

namespace "/api/v0" do

  post "/submit" do
    unless params.has_key?("submission_bundle")
      status 400
      return {error_message: "Request missing submission_bundle param"}.to_json
    end

    submission_filename = params["submission_bundle"]["filename"]
    result = Dir.mktmpdir do |dir|
      submission_path = File.join(dir, submission_filename)
      FileUtils.mv params["submission_bundle"]["tempfile"].path, submission_path
      EfilerService.run_efiler_command(get_api_client_mef_credentials, "submit", submission_path)
    end

    doc = Nokogiri::XML(result)
    if doc.css("SubmissionReceiptList SubmissionReceiptGrp SubmissionId").text.strip == File.basename(submission_filename, ".zip")
      status 201
      {status: "transmitted", result: result}.to_json
    else
      status 400
      {status: "failed", result: result}.to_json
    end
  rescue EfilerService::RetryableError
    halt 503, {error_message: "Failed with retryable error while submitting"}.to_json
  rescue
    halt 500, {error_message: "Failed while submitting"}.to_json
  end

  get "/submissions-status" do
    unless params.has_key?(:id)
      halt 400, {error_message: "Request missing id[] param(s)"}.to_json
    end

    response = EfilerService.run_efiler_command(get_api_client_mef_credentials, "submissions-status", *params[:id])
    submission_statuses = SubmissionsStatus.handle_submission_status_response(response)
    status 200
    submission_statuses.to_json
  rescue EfilerService::RetryableError
    halt 503, {error_message: "Failed with retryable error while getting submissions-status"}.to_json
  rescue
    halt 500, {error_message: "Failed while getting submissions-status"}.to_json
  end

  get "/acks" do
    unless params.has_key?(:id)
      status 400
      return {error_message: "Request missing id[] param(s)"}.to_json
    end

    response = EfilerService.run_efiler_command(get_api_client_mef_credentials, "acks", *params[:id])
    acks = Acks.handle_ack_response(response)
    status 200
    acks.to_json
  rescue EfilerService::RetryableError
    halt 503, {error_message: "Failed with retryable error while getting acks"}.to_json
  rescue
    halt 500, {exception: "Failed while getting acks"}.to_json
  end
end
