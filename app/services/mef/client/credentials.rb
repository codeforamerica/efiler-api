module Mef
  module Client
    class Credentials
      KEYSTORE_PASSWORD = "password"
      TEST_CDS = {"test" => "T", "prod" => "P"}

      attr_reader :etin, :app_sys_id, :test_cd, :private_key, :certificate

      def initialize(app_sys_id:, etin:, cert_base64:, mef_env:, **)
        pkcs12 = OpenSSL::PKCS12.new(Base64.decode64(cert_base64), KEYSTORE_PASSWORD)
        @etin = etin
        @app_sys_id = app_sys_id
        @test_cd = TEST_CDS.fetch(mef_env)
        @private_key = pkcs12.key
        @certificate = pkcs12.certificate
      end
    end
  end
end
