require "rails_helper"

describe MefService do
  let(:mef_credentials) { {mef_env: "test", app_sys_id: "foo", etin: "bar", cert_base64: "baz"} }

  before do
    allow(described_class).to receive(:create_config_dir)
    allow(described_class).to receive(:ensure_gyr_efiler_downloaded).and_return("/tmp/hypothetical_classes.zip")
  end

  describe "#get_api_client_mef_credentials" do
    let(:mock_secrets_manager_client) { instance_double(Aws::SecretsManager::Client) }
    let(:client_app_name) { "ClientAppName" }
    before do
      allow(Aws::SecretsManager::Client).to receive(:new).and_return(mock_secrets_manager_client)
      allow(mock_secrets_manager_client).to receive(:get_secret_value)
    end

    it "gets the credentials corresponding to the client app name in the jwt and converts keys to symbols" do
      secrets_hash = {"mef_env" => "test", "app_sys_id" => "foo", "etin" => "bar", "cert_base64" => "baz"}
      allow(mock_secrets_manager_client)
        .to receive(:get_secret_value)
        .with(secret_id: "efiler-api/demo/efiler-api-client-credentials/#{client_app_name}")
        .and_return(Aws::SecretsManager::Types::GetSecretValueResponse.new(secret_string: secrets_hash.to_json))

      expect(described_class.get_mef_credentials(client_app_name))
        .to eq({mef_env: "test", app_sys_id: "foo", etin: "bar", cert_base64: "baz"})
    end
  end

  describe ".run_efiler_command" do
    context "success" do
      let(:zip_data) do
        buf = Zip::OutputStream.write_buffer do |zio|
          zio.put_next_entry("filename.txt")
          zio.write "File contents"
        end
        buf.seek(0)
        buf.string
      end

      before do
        allow(Process).to receive(:spawn) do |_argv, chdir:, unsetenv_others:, in:|
          File.binwrite("#{chdir}/output/gyr-efiler-output.zip", zip_data)

          `true` # Run a successful command so that $? is set

          0 # Return a hypothetical process ID
        end

        allow(Process).to receive(:wait)
      end

      it "returns the file contents" do
        expect(described_class.run_efiler_command(mef_credentials)).to eq("File contents")
      end
    end

    context "command failure" do
      before do
        allow(Process).to receive(:spawn) do |_argv, chdir:, unsetenv_others:, in:|
          File.binwrite("#{chdir}/audit_log.txt", log_output)

          `false` # Run a command so that $? is set

          0 # Return a hypothetical process ID
        end

        allow(Process).to receive(:wait)
      end

      context "for unknown errors" do
        let(:log_output) { "Earlier line\nLogin Certificate: blahBlahBlah\nLog output" }

        it "raises an exception with the log output" do
          expect {
            described_class.run_efiler_command(mef_credentials)
          }.to raise_error(StandardError, "Earlier line\nLogin Certificate: blahBlahBlah\nLog output")
        end
      end

      context "when the cause is a gyr-efiler socket timeout" do
        let(:log_output) { "Earlier line\nLogin Certificate: blahBlahBlah\nTransaction Result: java.net.SocketTimeoutException: Read timed out\nLog output" }

        it "raises a RetryableError" do
          expect {
            described_class.run_efiler_command(mef_credentials)
          }.to raise_error(MefService::RetryableError)
        end
      end

      context "when the cause is a gyr-efiler login moved temporarily" do
        let(:log_output) do
          <<~AUDIT_LOG
            Name of Service Call: Login
            Message ID of Service Call: abcdefg
            Transaction Submission Date/Time: 2021-09-11T11:58:02Z
            ETIN of Service Call: 1234
            ASID: 121212
            Toolkit Version: 2020v11.1
            Request data: N/A
            Name of Service Call: Login
            Message ID of Service Call: abcdefg
            Transaction Result: The server sent HTTP status code 302: Moved Temporarily
          AUDIT_LOG
        end

        it "raises a RetryableError" do
          expect {
            described_class.run_efiler_command(mef_credentials)
          }.to raise_error(MefService::RetryableError)
        end
      end

      context "when there was a SOAP connect time out" do
        let(:log_output) do
          <<~AUDIT_LOG
            Name of Service Call: Login
            Message ID of Service Call: abcdefg
            Transaction Submission Date/Time: 2021-09-20T22:33:26Z
            ETIN of Service Call: 1234
            ASID: 121212
            Login Certificate: abc123
            Toolkit Version: 2020v11.1
            Request data: N/A
            Name of Service Call: Login
            Message ID of Service Call: abcdefg
            Transaction IRS Response Date/Time:
            Transaction Result: Fault String: Error while sending a request to http://MeF-A2A-Remote/a2a/mef/Login : connect timed out - Fault Code: soap:Server - Detail: <?xml version="1.0" encoding="UTF-8"?>__
          AUDIT_LOG
        end

        it "raises a RetryableError" do
          expect {
            described_class.run_efiler_command(mef_credentials)
          }.to raise_error(MefService::RetryableError)
        end
      end

      context "when 'unauthorized' for efile" do
        let(:log_output) { "Earlier line\nLogin Certificate: blahBlahBlah\nTransaction Result: The server sent HTTP status code 401: Unauthorized\nLog output" }

        it "raises a RetryableError" do
          expect {
            described_class.run_efiler_command(mef_credentials)
          }.to raise_error(MefService::RetryableError)
        end
      end

      context "when failed to parse XML" do
        let(:log_output) { "Transaction Result: Fault String: IDP Rule 'MeF Process Error IDP Rule' aborted processing.__Failed to parse XML document: Characters larger than 4 bytes are not supported: byte 0x8b implies a length of more than 4 bytes - Fault Code: soap:Client - Detail: <?xml version=\"1.0\" encoding=\"UTF-8\"?>" }

        it "raises a RetryableError" do
          expect {
            described_class.run_efiler_command(mef_credentials)
          }.to raise_error(MefService::RetryableError)
        end
      end

      context "when session token invalid" do
        let(:log_output) { "Transaction Result: Fault String: IDP Rule 'MeF Process Error IDP Rule' aborted processing.__Cookie validation for session 'IkH...g==' failed because 'Invalid session token' - Fault Code: soap:Client - Detail: <?xml version=\"1.0\" encoding=\"UTF-8\"?>__" }

        it "raises a RetryableError" do
          expect {
            described_class.run_efiler_command(mef_credentials)
          }.to raise_error(MefService::RetryableError)
        end
      end

      context "when there was an Internal Server Error" do
        let(:log_output) do
          <<~LOG
            Name of Service Call: Login
            Message ID of Service Call: REDACTED
            Transaction Result: The server sent HTTP status code 500: Internal Server Error
          LOG
        end

        it "raises a RetryableError" do
          expect {
            described_class.run_efiler_command(mef_credentials)
          }.to raise_error(MefService::RetryableError)
        end
      end

      context "when javax.net.ssl.SSLException" do
        let(:log_output) do
          <<~LOG
            Name of Service Call: Login
            Message ID of Service Call: REDACTED
            Transaction Result: HTTP transport error: javax.net.ssl.SSLException: Received fatal alert: internal_error>
          LOG
        end

        it "raises a RetryableError" do
          expect {
            described_class.run_efiler_command(mef_credentials)
          }.to raise_error(MefService::RetryableError)
        end
      end

      context "when java.net.ConnectException" do
        let(:log_output) do
          <<~LOG
            Name of Service Call: Login
            Message ID of Service Call: REDACTED
            Transaction Result: HTTP transport error: java.net.ConnectException: Connection refused (Connection refused)>
          LOG
        end

        it "raises a RetryableError" do
          expect {
            described_class.run_efiler_command(mef_credentials)
          }.to raise_error(MefService::RetryableError)
        end
      end
    end
  end
end
