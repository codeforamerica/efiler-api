require 'sinatra/base'

module Sinatra
  module JwtAuth
    def authenticate_jwt
      before do
        verify_client_name_and_signature
      end
    end

    def verify_client_name_and_signature
      authorization_header = request.env['HTTP_AUTHORIZATION']
      token = JWT::EncodedToken.new(authorization_header.delete_prefix("Bearer "))

      allowed_client_names = Dir.children("client_public_keys").map do |public_key_filename|
        File.basename(public_key_filename, ".pub")
      end
      token.verify_claims!(iss: allowed_client_names)

      client_name = token.unverified_payload["iss"]
      client_public_key_filename = File.join("client_public_keys", "#{client_name}.pub")
      client_public_key = OpenSSL::PKey::RSA.new(File.read(client_public_key_filename))
      token.verify_signature!(algorithm: 'RS256', key: client_public_key)
    rescue JWT::InvalidIssuerError
      halt 500, { error_message: "Invalid client ID in JWT" }.to_json
    rescue StandardError => e
      halt 500, { exception: e.detailed_message }.to_json
    end

    def api_client_name
      authorization_header = request.env['HTTP_AUTHORIZATION']
      token = JWT::EncodedToken.new(authorization_header.delete_prefix("Bearer "))
      token.unverified_payload["iss"]
    end

    def get_api_client_mef_credentials
      aws_credentials = Aws::Credentials.new(ENV["AWS_ACCESS_KEY_ID"], ENV["AWS_SECRET_ACCESS_KEY"])
      aws_client = Aws::SecretsManager::Client.new(region: 'us-east-1', credentials: aws_credentials)
      response = aws_client.get_secret_value(secret_id: "efiler-api-client-mef-credentials/#{api_client_name}")
      JSON.parse(response.secret_string).transform_keys { |k| k.to_sym }
    end
  end

  register JwtAuth
  helpers JwtAuth
end