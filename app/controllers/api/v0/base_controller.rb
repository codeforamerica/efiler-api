class Api::V0::BaseController < ApplicationController
  before_action :generate_api_request_id
  before_action :verify_client_name_and_signature

  rescue_from MefService::RetryableError, with: :retryable_mef_error
  rescue_from ActionController::ParameterMissing, with: :show_errors
  rescue_from Aws::SecretsManager::Errors::ResourceNotFoundException, with: :unauthorized
  rescue_from JWT::VerificationError, with: :unauthorized

  attr_reader :api_request_id
  def generate_api_request_id
    @api_request_id = SecureRandom.uuid
  end

  def retryable_mef_error
    render json: "Error contacting MeF, please try again", status: :bad_gateway
  end

  def show_errors(exception)
    render json: exception.message, status: :bad_request
  end

  def unauthorized
    head :unauthorized
  end

  def verify_client_name_and_signature
    authorization_header = request.headers["HTTP_AUTHORIZATION"]
    token = JWT::EncodedToken.new(authorization_header.delete_prefix("Bearer "))

    client_credentials = MefService.get_mef_credentials(api_client_name)
    client_public_key_base64 = client_credentials[:efiler_api_public_key]
    client_public_key = OpenSSL::PKey::RSA.new(Base64.decode64(client_public_key_base64))
    token.verify_signature!(algorithm: "RS256", key: client_public_key)
  end

  def api_client_name
    authorization_header = request.headers["HTTP_AUTHORIZATION"]
    token = JWT::EncodedToken.new(authorization_header.delete_prefix("Bearer "))
    token.unverified_payload["iss"]
  end
end
