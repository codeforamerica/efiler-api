class Api::V0::BaseController < ApplicationController
  before_action :generate_api_request_id
  before_action :verify_client_name_and_signature

  rescue_from MefService::RetryableError, with: :retryable_mef_error
  rescue_from ActionController::ParameterMissing, with: :showable_error
  rescue_from Aws::SecretsManager::Errors::ServiceError, with: :aws_error
  rescue_from JWT::VerificationError, with: :jwt_error

  attr_reader :api_request_id
  def generate_api_request_id
    @api_request_id = SecureRandom.uuid
  end

  def retryable_mef_error(exception)
    Rails.logger.error("Encountered retryable error while contacting MeF: #{exception}")
    render json: "Error contacting MeF, please try again", status: :bad_gateway
  end

  def showable_error(exception)
    Rails.logger.error("Encountered showable error: #{exception}")
    render json: exception.message, status: :bad_request
  end

  def aws_error(exception)
    Rails.logger.error("Encountered error while contacting AWS: #{exception}")
    head :unauthorized
  end

  def jwt_error(exception)
    Rails.logger.error("Encountered JWT verification error: #{exception}")
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
