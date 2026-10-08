require "rails_helper"
require "support/mef_test_credentials"

describe Mef::Client::Envelope do
  let(:credentials) { MefTestCredentials.build }
  let(:release) { Mef::Client::Releases::ProcessingYear2027 }
  let(:envelope) { described_class.new(credentials, release) }
  let(:ns) { Mef::Client::Signer::NAMESPACES.merge("saml" => "urn:oasis:names:tc:SAML:1.0:assertion", "ns2" => described_class::TRANSMITTER) }
  let(:saml_assertion) do
    Nokogiri::XML(<<~XML).root
      <saml:Assertion xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion" AssertionID="a-1" MajorVersion="1" MinorVersion="1"><saml:AttributeStatement><saml:Attribute AttributeName="SMSESSION"><saml:AttributeValue>session-value</saml:AttributeValue></saml:Attribute></saml:AttributeStatement></saml:Assertion>
    XML
  end

  def header_values(doc)
    doc.at_xpath("//mefhdr:MeFHeader", ns).element_children.to_h { |el| [el.name, el.text] }
  end

  describe ".login" do
    it "writes the MeFHeader fields in schema order, requesting a session key" do
      doc = envelope.login

      values = header_values(doc)
      expect(values.keys).to eq(%w[MessageID Action MessageTs ETIN SessionKeyCd TestCd AppSysID WSDLVersionNum ClientSoftwareTxt])
      expect(values).to include(
        "Action" => "http://www.irs.gov/a2a/mef/Login",
        "ETIN" => "12345",
        "SessionKeyCd" => "Y",
        "TestCd" => "T",
        "AppSysID" => "12345678",
        "WSDLVersionNum" => "10.A"
      )
      expect(values["MessageID"]).to match(/\A12345#{Time.now.strftime("%Y%j")}[a-z0-9]{8}\z/)
    end

    it "gives the MeFHeader and the Body the wsu:Ids the signature references" do
      doc = envelope.login

      expect(doc.at_xpath("//mefhdr:MeFHeader/@wsu:Id", ns)).to be_present
      expect(doc.at_xpath("/S:Envelope/S:Body/@wsu:Id", ns)).to be_present
      expect(doc.at_xpath("/S:Envelope/S:Body/*").name).to eq("LoginRequest")
    end

    it "sets TestCd from the client's MeF environment" do
      expect(header_values(described_class.new(MefTestCredentials.build(mef_env: "prod"), release).login)["TestCd"]).to eq("P")
    end
  end

  describe ".logout" do
    it "carries the session security header and declines a new session key" do
      doc = envelope.logout(saml_assertion)

      expect(header_values(doc)).to include("Action" => "http://www.irs.gov/a2a/mef/Logout", "SessionKeyCd" => "N")
      expect(doc.at_xpath("//wsse:Security/wsse:UsernameToken/wsse:Username", ns).text).to eq("12345678")
      expect(Time.iso8601(doc.at_xpath("//wsu:Timestamp/wsu:Expires", ns).text) - Time.iso8601(doc.at_xpath("//wsu:Timestamp/wsu:Created", ns).text)).to eq(5.minutes)
    end

    it "echoes the Login response's SAML assertion unchanged" do
      echoed = envelope.logout(saml_assertion).at_xpath("//wsse:Security/saml:Assertion", ns)

      expect(echoed.canonicalize(Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0)).to eq(saml_assertion.canonicalize(Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0))
    end
  end

  describe ".transmitter" do
    it "uses the toolkit's MTOM Action and wraps the given request element" do
      doc = envelope.transmitter(saml_assertion,
        operation: "GetAcks",
        body: %(<ns2:GetAcksRequest xmlns:ns2="#{described_class::TRANSMITTER}"><ns2:SubmissionIdList><ns2:SubmissionId>1234562026280abcdefg</ns2:SubmissionId></ns2:SubmissionIdList></ns2:GetAcksRequest>))

      expect(header_values(doc)).to include("Action" => "http://localhost:9080/a2a/mef/mtom/GetAcks", "SessionKeyCd" => "Y")
      expect(doc.at_xpath("/S:Envelope/S:Body/ns2:GetAcksRequest/ns2:SubmissionIdList/ns2:SubmissionId", ns).text).to eq("1234562026280abcdefg")
    end
  end
end
