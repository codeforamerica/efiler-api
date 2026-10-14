module MefTestCredentials
  def self.key
    @key ||= OpenSSL::PKey::RSA.new(2048)
  end

  def self.certificate
    @certificate ||= OpenSSL::X509::Certificate.new.tap do |cert|
      cert.version = 2
      cert.serial = 1
      cert.subject = cert.issuer = OpenSSL::X509::Name.parse("/CN=efiler-api-test")
      cert.public_key = key.public_key
      cert.not_before = Time.now - 60
      cert.not_after = Time.now + 3600
      cert.sign(key, OpenSSL::Digest.new("SHA256"))
    end
  end

  def self.cert_base64
    Base64.strict_encode64(OpenSSL::PKCS12.create(Mef::Client::Credentials::KEYSTORE_PASSWORD, "mef", key, certificate).to_der)
  end

  def self.build(mef_env: "test")
    Mef::Client::Credentials.new(app_sys_id: "12345678", etin: "12345", cert_base64:, mef_env:)
  end
end
