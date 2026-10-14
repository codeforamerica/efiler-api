require "rails_helper"
require "support/mef_test_credentials"

# Checks the client against each release's IRS WSDL/XSD files, which are downloaded by
# script/download_mef_wsdls.rb because they may not be committed.
describe "MeF client conformance to the IRS WSDLs" do
  let(:credentials) { MefTestCredentials.build }
  let(:saml_assertion) { Nokogiri::XML(%(<saml:Assertion xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion"/>)).root }

  def schema(release, file)
    path = release.wsdl_dir.join(file).to_s
    Nokogiri::XML::Schema.from_document(Nokogiri::XML(File.read(path), path))
  end

  def validation_errors(schema, element)
    schema.validate(Nokogiri::XML(element.to_xml)).map(&:message)
  end

  Mef::Client::Releases::ALL.each do |release|
    context "release #{release.wsdl_version}" do
      let(:envelope) { Mef::Client::Envelope.new(credentials, release) }

      # Where the files can be downloaded, a release whose files are missing (or whose version is
      # mistyped) fails instead of being skipped.
      before do
        next if release.wsdl_dir.exist?

        message = "#{release.wsdl_dir} is missing; run script/download_mef_wsdls.rb"
        ENV["MEF_WSDLS_S3_BUCKET"].present? ? raise(message) : skip(message)
      end

      it "declares the WSDLVersionNum that its MeFHeader.xsd fixes" do
        xsd = Nokogiri::XML(File.read(release.wsdl_dir.join("MeFHeader.xsd")))

        expect(xsd.at_xpath("//xs:element[@name='WSDLVersionNum']/@fixed", "xs" => "http://www.w3.org/2001/XMLSchema").value).to eq(release.wsdl_version)
      end

      it "builds MeFHeaders that MeFHeader.xsd accepts" do
        header_schema = schema(release, "MeFHeader.xsd")
        headers = [envelope.login, envelope.logout(saml_assertion), envelope.transmitter(saml_assertion, operation: "GetAcks", body: "")]
          .map { |doc| doc.at_xpath("//mefhdr:MeFHeader", "mefhdr" => Mef::Client::Envelope::MEF_HEADER) }

        expect(headers.flat_map { |header| validation_errors(header_schema, header) }).to be_empty
      end

      it "builds Login and Logout requests that MeFMSIServices.xsd accepts" do
        msi_schema = schema(release, "MeFMSIServices.xsd")
        bodies = [envelope.login, envelope.logout(saml_assertion)]
          .map { |doc| doc.at_xpath("/S:Envelope/S:Body/*", "S" => Mef::Client::Envelope::SOAP_ENV) }

        expect(bodies.flat_map { |body| validation_errors(msi_schema, body) }).to be_empty
      end

      # An MTOM element is schema-valid in its logical form, with the xop:Include replaced by
      # the base64 content it stands for.
      it "builds transmitter requests that MeFTransmitterServiceMTOM.xsd accepts" do
        transmitter_schema = schema(release, "MeFTransmitterServiceMTOM.xsd")
        ids = ["1234562026280abcdefg", "1234562026280hijklmn"]
        requests = [
          Mef::Client::Requests.get_acks(ids),
          Mef::Client::Requests.get_submissions_status(ids),
          Mef::Client::Requests.send_submissions(ids.first, Time.current, "attachment")
        ].map do |xml|
          Nokogiri::XML(xml).tap do |doc|
            doc.xpath("//xop:Include", "xop" => Mef::Client::Mtom::XOP).each { |include| include.replace(Base64.strict_encode64("zip")) }
          end.root
        end

        expect(requests.flat_map { |request| validation_errors(transmitter_schema, request) }).to be_empty
      end
    end
  end
end
