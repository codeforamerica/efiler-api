require "sinatra/base"

# See https://sinatrarb.com/extensions.html for more context about how this code is structured

module Sinatra
  module EfilerApiClientAuth
    def authenticate_jwt
      before do
        verify_client_name_and_signature
      end
    end

    def verify_client_name_and_signature
      authorization_header = request.env["HTTP_AUTHORIZATION"]
      token = JWT::EncodedToken.new(authorization_header.delete_prefix("Bearer "))

      client_credentials = get_api_client_mef_credentials
      client_public_key_base64 = client_credentials[:efiler_api_public_key]
      client_public_key = OpenSSL::PKey::RSA.new(client_public_key_base64)
      token.verify_signature!(algorithm: "RS256", key: client_public_key)
    rescue JWT::InvalidIssuerError
      halt 401, {error_message: "Invalid client ID in JWT"}.to_json
    rescue JWT::VerificationError
      halt 401, {error_message: "Client ID does not match private key used to sign JWT"}.to_json
    rescue
      halt 500, {error_message: "Failed while authenticating request JWT"}.to_json
    end

    def api_client_name
      authorization_header = request.env["HTTP_AUTHORIZATION"]
      token = JWT::EncodedToken.new(authorization_header.delete_prefix("Bearer "))
      token.unverified_payload["iss"]
    rescue
      halt 500, {error_message: "Failed while reading API client name from JWT"}.to_json
    end

    def get_api_client_mef_credentials
      aws_client = Aws::SecretsManager::Client.new
      response = aws_client.get_secret_value(secret_id: "efiler-api-client-mef-credentials/#{api_client_name}")
      JSON.parse(response.secret_string).transform_keys { |k| k.to_sym }
    rescue Seahorse::Client::NetworkingError
      halt 503, {error_message: "Failed to reach AWS to retrieve API client's MeF credentials"}.to_json
    rescue
      halt 500, {error_message: "Failed while retrieving API client's MeF credentials"}.to_json
    end
  end

  register EfilerApiClientAuth
  helpers EfilerApiClientAuth
end
