require "rails_helper"
require "support/mef_test_credentials"
require "support/mef_responses"

describe Mef::Client::Session do
  let(:credentials) { MefTestCredentials.build }
  let(:release) { Mef::Client::Releases::ProcessingYear2027 }
  let(:host) { "https://la.alt.www4.irs.gov" }
  let(:ns) { Mef::Client::Signer::NAMESPACES.merge("saml" => MefResponses::SAML, "mtx" => Mef::Client::Envelope::TRANSMITTER) }
  let(:ack_xml) { file_fixture("irs_acknowledgement.xml").read }

  def soap_part(request)
    Mef::Client::Mtom.parse(request.headers["Content-Type"], request.body).first
  end

  before do
    stub_request(:post, "#{host}/a2a/mef/Login").to_return(MefResponses.login(cookie: "jsession-1"))
    stub_request(:post, "#{host}/a2a/mef/Logout").to_return(MefResponses.logout)
  end

  describe ".open" do
    before do
      stub_request(:post, "#{host}/a2a/mef/mtom/GetAcks")
        .to_return(MefResponses.transmitter("GetAcks", "AcknowledgementListAttMTOM", ack_xml, cookie: "jsession-2"))
    end

    it "logs in with a signed request, runs the operation within the session, and logs out" do
      result = described_class.open(credentials, release) { |session| session.get_acks(["1234562026280abcdefg"]) }

      expect(result).to eq(ack_xml)
      expect(WebMock).to have_requested(:post, "#{host}/a2a/mef/Login").with { |request|
        request.headers["Soapaction"] == %("http://www.irs.gov/a2a/mef/Login") &&
          Nokogiri::XML(request.body).at_xpath("//wsse:Security/ds:Signature", ns).present?
      }
      expect(WebMock).to have_requested(:post, "#{host}/a2a/mef/Logout")
    end

    it "carries every session cookie and echoes the Login SAML assertion, following the cookies as MeF reissues them" do
      described_class.open(credentials, release) { |session| session.get_acks(["1234562026280abcdefg"]) }

      expect(WebMock).to have_requested(:post, "#{host}/a2a/mef/mtom/GetAcks").with { |request|
        doc = soap_part(request)
        request.headers["Cookie"] == "JSESSIONID=jsession-1; dc=dcs" &&
          request.headers["Soapaction"] == %("http://www.irs.gov/a2a/mef/mtom/GetAcks") &&
          doc.at_xpath("//wsse:Security/saml:Assertion//saml:AttributeValue", ns)&.text == "session-value" &&
          doc.at_xpath("//mtx:GetAcksRequest/mtx:SubmissionIdList/mtx:SubmissionId", ns)&.text == "1234562026280abcdefg"
      }
      expect(WebMock).to have_requested(:post, "#{host}/a2a/mef/Logout").with(headers: {"Cookie" => "JSESSIONID=jsession-2; dc=dcs"})
    end

    it "echoes a newer SAML assertion when a later response carries one" do
      stub_request(:post, "#{host}/a2a/mef/mtom/GetAcks")
        .to_return(MefResponses.transmitter("GetAcks", "AcknowledgementListAttMTOM", ack_xml, assertion: MefResponses.saml_assertion("renewed")))

      described_class.open(credentials, release) { |session| session.get_acks(["1234562026280abcdefg"]) }

      expect(WebMock).to have_requested(:post, "#{host}/a2a/mef/Logout").with { |request|
        Nokogiri::XML(request.body).at_xpath("//saml:AttributeValue", ns)&.text == "renewed"
      }
    end

    # MeF signs the assertion, so it must survive the trip into our request intact, including
    # namespaces it inherited from the response envelope.
    it "echoes the assertion canonically unchanged, even when it relies on namespaces declared above it" do
      inherited = %(<saml:Assertion AssertionID="a-1" MajorVersion="1" MinorVersion="1"><ds:Signature><ds:SignatureValue>c2ln&#13;\nbmVk</ds:SignatureValue></ds:Signature></saml:Assertion>)
      login = MefResponses.login(assertion: inherited, envelope_namespaces: %( xmlns:saml="#{MefResponses::SAML}" xmlns:ds="http://www.w3.org/2000/09/xmldsig#"))
      stub_request(:post, "#{host}/a2a/mef/Login").to_return(login)
      original = Nokogiri::XML(login[:body]).at_xpath("//saml:Assertion", ns).canonicalize(Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0)

      described_class.open(credentials, release) { |session| session.get_acks(["1234562026280abcdefg"]) }

      expect(WebMock).to have_requested(:post, "#{host}/a2a/mef/mtom/GetAcks").with { |request|
        soap_part(request).at_xpath("//wsse:Security/saml:Assertion", ns).canonicalize(Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0) == original
      }
    end

    it "keeps the operation's result when Logout fails, so a transmitted submission isn't retried and sent twice" do
      stub_request(:post, "#{host}/a2a/mef/Logout").to_return(MefResponses.fault("Logout failed", classification: "SYSTEM_ERROR"))
      allow(Rails.logger).to receive(:warn)

      result = described_class.open(credentials, release) { |session| session.get_acks(["1234562026280abcdefg"]) }

      expect(result).to eq(ack_xml)
      expect(Rails.logger).to have_received(:warn).with("MeF Logout failed: MefService::RetryableError")
    end

    it "still logs out when the operation fails" do
      stub_request(:post, "#{host}/a2a/mef/mtom/GetAcks").to_return(MefResponses.fault("Bad request", classification: "REQUEST_ERROR"))

      expect { described_class.open(credentials, release) { |session| session.get_acks(["1234562026280abcdefg"]) } }
        .to raise_error(Mef::Client::Error)
      expect(WebMock).to have_requested(:post, "#{host}/a2a/mef/Logout")
    end
  end

  describe "#login!" do
    it "requires the SAML assertion that later requests must echo" do
      stub_request(:post, "#{host}/a2a/mef/Login").to_return(MefResponses.login(assertion: ""))

      expect { described_class.new(credentials, release).login! }.to raise_error(Mef::Client::Error, /no SAML assertion/)
    end

    it "requires the JSESSIONID cookie that carries the session" do
      stub_request(:post, "#{host}/a2a/mef/Login").to_return(MefResponses.login(cookie: nil))

      expect { described_class.new(credentials, release).login! }.to raise_error(Mef::Client::Error, /no JSESSIONID/)
    end

    it "talks to production MeF for a production client" do
      stub_request(:post, "https://la.www4.irs.gov/a2a/mef/Login").to_return(MefResponses.login)

      described_class.new(MefTestCredentials.build(mef_env: "prod"), release).login!

      expect(WebMock).to have_requested(:post, "https://la.www4.irs.gov/a2a/mef/Login")
    end
  end

  describe "#send_submissions" do
    let(:receipt_xml) { %(<SubmissionReceiptList xmlns="http://www.irs.gov/efile"><Cnt>1</Cnt></SubmissionReceiptList>) }
    let(:bundle) { "PK\x03\x04 a submission bundle".b }

    before do
      stub_request(:post, "#{host}/a2a/mef/mtom/SendSubmissions")
        .to_return(MefResponses.transmitter("SendSubmissions", "SubmissionRcptListAttMTOM", receipt_xml))
    end

    it "sends the bundle, stored uncompressed as <SubmissionId>.zip, in a container zip attachment" do
      postmark = Time.utc(2026, 10, 13, 14, 0, 0.5r)

      result = described_class.open(credentials, release) { |session| session.send_submissions("1234562026286subtest", bundle, postmarked_at: postmark) }

      expect(result).to eq(receipt_xml)
      expect(WebMock).to have_requested(:post, "#{host}/a2a/mef/mtom/SendSubmissions").with { |request|
        doc, attachments = Mef::Client::Mtom.parse(request.headers["Content-Type"], request.body)
        container = Mef::Client::Mtom.resolve(doc.at_xpath("//mtx:SubmissionsAttMTOM", ns), attachments)
        entries = nil
        Zip::File.open_buffer(StringIO.new(container)) { |zip| entries = zip.entries.map { |e| [e.name, e.compression_method, zip.read(e)] } }
        # MeF streams the container, so the local header itself must carry the CRC and sizes.
        version, flags = container[4, 4].unpack("vv")
        crc, compressed_size, size = container[14, 12].unpack("VVV")

        entries == [["1234562026286subtest.zip", Zip::Entry::STORED, bundle]] &&
          version < 45 && flags & 0x8 == 0 &&
          [crc, compressed_size, size] == [Zlib.crc32(bundle), bundle.bytesize, bundle.bytesize] &&
          doc.at_xpath("//mtx:SubmissionData/mtx:SubmissionId", ns).text == "1234562026286subtest" &&
          doc.at_xpath("//mtx:SubmissionData/mtx:ElectronicPostmarkTs", ns).text == "2026-10-13T14:00:00.500Z"
      }
    end
  end

  describe "error classification" do
    def get_acks
      described_class.open(credentials, release) { |session| session.get_acks(["1234562026280abcdefg"]) }
    end

    {
      "a SYSTEM_ERROR fault" => MefResponses.fault("Internal failure", classification: "SYSTEM_ERROR"),
      "a RESOURCE_UNAVAILABLE fault" => MefResponses.fault("Down for maintenance", classification: "RESOURCE_UNAVAILABLE"),
      "a session-limit fault" => MefResponses.fault("Session limit reached"),
      "a session-cookie fault" => MefResponses.fault("Cookie validation for session failed"),
      "a 302 maintenance redirect" => {status: 302, headers: {"Location" => "https://www.irs.gov/maintenance"}, body: ""},
      "a 503" => {status: 503, headers: {"Content-Type" => "text/html"}, body: "<html>Unavailable</html>"}
    }.each do |description, response|
      it "retries #{description}" do
        stub_request(:post, "#{host}/a2a/mef/mtom/GetAcks").to_return(response)

        expect { get_acks }.to raise_error(MefService::RetryableError)
      end
    end

    it "retries connection failures" do
      stub_request(:post, "#{host}/a2a/mef/mtom/GetAcks").to_raise(Faraday::ConnectionFailed.new("connection refused"))

      expect { get_acks }.to raise_error(MefService::RetryableError, /ConnectionFailed/)
    end

    it "does not retry a REQUEST_ERROR fault, and reports its classification, code and message" do
      stub_request(:post, "#{host}/a2a/mef/mtom/GetAcks").to_return(MefResponses.fault("Submission ID is invalid", classification: "REQUEST_ERROR"))

      expect { get_acks }.to raise_error(an_instance_of(Mef::Client::Error).and(having_attributes(message: "MeF /a2a/mef/mtom/GetAcks fault (HTTP 500, REQUEST_ERROR, MEF-1): Submission ID is invalid")))
    end

    it "does not retry an HTTP status MeF doesn't use for transient trouble" do
      stub_request(:post, "#{host}/a2a/mef/mtom/GetAcks").to_return(status: 404, body: "")

      expect { get_acks }.to raise_error(an_instance_of(Mef::Client::Error))
    end
  end
end
