require 'sinatra/base'

module Sinatra
  module JwtAuth
    def authenticate_jwt
      before do
        authorization_header = request.env['HTTP_AUTHORIZATION']
        bearer = authorization_header.delete_prefix("Bearer ")
        token = JWT::EncodedToken.new(bearer)

        allowed_client_names = Dir.children("client_public_keys").map do |public_key_filename|
          File.basename(public_key_filename, ".pub")
        end
        token.verify_claims!(iss: allowed_client_names)

        client_name = token.unverified_payload["iss"]
        client_public_key_filename = File.join("client_public_keys", "#{client_name}.pub")
        client_public_key = OpenSSL::PKey::RSA.new(File.read(client_public_key_filename))
        token.verify_signature!(algorithm: 'RS256', key: client_public_key)
      rescue StandardError => e
        halt 500, { exception: e.detailed_message }.to_json
      end
    end
  end

  register JwtAuth
end