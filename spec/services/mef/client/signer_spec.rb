require "rails_helper"
require "support/mef_test_credentials"

describe Mef::Client::Signer do
  let(:credentials) { MefTestCredentials.build }
  let(:login_envelope) { Mef::Client::Envelope.new(credentials, Mef::Client::Releases::ProcessingYear2027).login }
  let(:ns) { described_class::NAMESPACES.merge("ec" => described_class::EXC_C14N) }
  let(:exclusive) { Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0 }

  # Verifies the way MeF must: from the serialized bytes, with the certificate taken from the
  # message's own BinarySecurityToken.
  def verify(xml)
    doc = Nokogiri::XML(xml)
    references_valid = doc.xpath("//ds:Reference", ns).all? do |reference|
      node = doc.at_xpath("//*[@wsu:Id='#{reference["URI"].delete_prefix("#")}']", ns)
      prefixes = reference.at_xpath(".//ec:InclusiveNamespaces", ns)["PrefixList"].split
      Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(node.canonicalize(exclusive, prefixes))) == reference.at_xpath("ds:DigestValue", ns).text
    end
    signed_info = doc.at_xpath("//ds:SignedInfo", ns)
    prefixes = signed_info.at_xpath("ds:CanonicalizationMethod/ec:InclusiveNamespaces", ns)["PrefixList"].split
    certificate = OpenSSL::X509::Certificate.new(Base64.decode64(doc.at_xpath("//wsse:BinarySecurityToken", ns).text))
    signature = Base64.decode64(doc.at_xpath("//ds:SignatureValue", ns).text)
    references_valid && certificate.public_key.verify(OpenSSL::Digest.new("SHA256"), signature, signed_info.canonicalize(exclusive, prefixes))
  end

  it "signs the MeFHeader and the Body so that the serialized envelope verifies against its own certificate" do
    doc = described_class.new(credentials).sign(login_envelope)

    expect(doc.xpath("//ds:Reference", ns).map { |r| doc.at_xpath("//*[@wsu:Id='#{r["URI"].delete_prefix("#")}']", ns).name }).to eq(%w[MeFHeader Body])
    expect(verify(Mef::Client::Envelope.serialize(doc))).to be(true)
  end

  it "produces a signature that no longer verifies once the signed MeFHeader changes" do
    doc = described_class.new(credentials).sign(login_envelope)
    doc.at_xpath("//mefhdr:ETIN", ns).content = "99999"

    expect(verify(Mef::Client::Envelope.serialize(doc))).to be(false)
  end
end
