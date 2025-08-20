require "rails_helper"

class FakeController < Api::V0::BaseController; end

describe FakeController, type: :controller do
  describe "#verify_client_name_and_signature" do
    # authorization_header = request.headers["HTTP_AUTHORIZATION"]
    # token = JWT::EncodedToken.new(authorization_header.delete_prefix("Bearer "))
    #
    # client_credentials = get_api_client_mef_credentials
    # client_public_key_base64 = client_credentials[:efiler_api_public_key]
    # client_public_key = OpenSSL::PKey::RSA.new(Base64.decode64(client_public_key_base64))
    # token.verify_signature!(algorithm: "RS256", key: client_public_key)
    it "verifies the request has a valid JWT with cert and client app name" do
      client_app_name = "FakeClientApp"

      allow_any_instance_of(Aws::SecretsManager::Client)
        .to receive(:get_secret_value)
              .with(secret_id: "efiler-api-client-mef-credentials/#{client_app_name}")
              .and_return({ mef_env: "test", app_sys_id: "foo", etin: "bar", cert_base64: "baz" })


      claim = { "iss" => client_app_name }
      request.headers["Authorization"] = "Bearer #{token}"

    end
  end

  describe "#get_api_client_mef_credentials" do
    it "returns the credentials from aws with symbols as keys" do
      client_app_name = "FakeClientApp"
      allow_any_instance_of(described_class).to receive(:api_client_name).and_return client_app_name

      secrets_manager_double = double
      allow(Aws::SecretsManager::Client).to receive(:new).and_return secrets_manager_double

      secrets_hash = { "mef_env" => "test", "app_sys_id" => "foo", "etin" => "bar", "cert_base64" => "baz" }
      get_secrets_value_response_double = Aws::SecretsManager::Types::GetSecretValueResponse.new(secret_string: secrets_hash.to_json)

      allow(secrets_manager_double)
        .to receive(:get_secret_value)
              .with(secret_id: "efiler-api-client-mef-credentials/#{client_app_name}")
              .and_return(get_secrets_value_response_double)

      expect(described_class.new.get_api_client_mef_credentials)
        .to eq({ mef_env: "test", app_sys_id: "foo", etin: "bar", cert_base64: "baz" })
    end
  end

  xdescribe "#api_client_name" do
    controller do
      def index
        return api_client_name
      end
    end

    it "gets the api client name from the iss" do
      allow_any_instance_of(described_class).to receive(:verify_client_name_and_signature)
      token_double = double
      allow(token_double).to receive(:unverified_payload).and_return({"iss" => "Client App"})
      allow(JWT::EncodedToken).to receive(:new).and_return token_double
      request.headers["Authorization"] = "Bearer #{token_double}"

      get :index

      expect(response.body).to eq "Client App"
    end
  end

  context "error handling" do
    before do
      allow_any_instance_of(described_class).to receive(:verify_client_name_and_signature).and_return(true)
    end

    context "when it encounters a retryable error" do
      controller do
        def index
          raise MefService::RetryableError
          head :ok
        end
      end

      it "returns a bad gateway response" do
        get :index

        expect(response.body).to eq("Error contacting MeF, please try again")
        expect(response.status).to eq(502)
      end
    end

    context "when it encounters a missing parameters error" do
      controller do
        def index
          params = ActionController::Parameters.new(a: {})
          params.fetch(:boop)
          head :ok
        end
      end

      it "returns a bad request response" do
        get :index

        expect(response.body).to eq("param is missing or the value is empty or invalid: boop")
        expect(response).to be_bad_request
      end
    end

    xcontext "when it encounters an aws resource not found error" do
      controller do
        def index
          raise Aws::SecretsManager::Errors::ResourceNotFoundException(nil, nil)
          head :ok
        end
      end

      it "returns unauthorized" do
        get :index

        expect(response).to be_unauthorized
      end
    end

    context "when it encounters a jwt verification error" do
      controller do
        def index
          raise JWT::VerificationError
          head :ok
        end
      end

      it "returns unauthorized" do
        get :index

        expect(response).to be_unauthorized
      end
    end
  end
end
