require "rails_helper"

describe Mef::Client::Mtom do
  let(:envelope) { %(<?xml version="1.0"?><S:Envelope xmlns:S="#{Mef::Client::Envelope::SOAP_ENV}"><S:Body><Att><xop:Include xmlns:xop="#{described_class::XOP}" href="cid:att-1"/></Att></S:Body></S:Envelope>) }
  # Binary content that looks like MIME framing must survive untouched.
  let(:attachment) { "PK\x03\x04\r\n--uuid:not-the-boundary\r\n\r\n\x00\xFF".b }

  it "frames the envelope as the root XOP part, followed by each attachment, as the toolkit does" do
    message = described_class.build(envelope, "att-1" => attachment)

    expect(message.content_type).to match(%r{\Amultipart/related;start="<rootpart\*[0-9a-f-]+@example\.jaxws\.sun\.com>";type="application/xop\+xml";boundary="uuid:[0-9a-f-]+";start-info="text/xml"\z})
    expect(message.body).to include(%(Content-Type: application/xop+xml;charset=utf-8;type="text/xml"\r\nContent-Transfer-Encoding: binary\r\n\r\n<?xml))
    expect(message.body).to include("Content-ID: <att-1>\r\nContent-Type: application/octet-stream\r\n".b)
    expect(message.body).to end_with("\r\n--#{message.content_type[/boundary="([^"]+)"/, 1]}--")
  end

  it "parses what it builds, resolving xop:Include to the attachment's exact bytes" do
    message = described_class.build(envelope, "att-1" => attachment)

    doc, attachments = described_class.parse(message.content_type, message.body)

    expect(doc.root.name).to eq("Envelope")
    expect(described_class.resolve(doc.at_xpath("//Att"), attachments)).to eq(attachment)
  end

  it "parses a plain text/xml response, as SOAP faults arrive, with no attachments" do
    doc, attachments = described_class.parse("text/xml; charset=utf-8", envelope)

    expect(doc.root.name).to eq("Envelope")
    expect(attachments).to be_empty
  end

  # MeF inlines a small attachment as base64 instead of moving it to its own part.
  it "decodes an attachment carried inline as base64 rather than referenced with xop:Include" do
    doc = Nokogiri::XML(%(<Att>#{Base64.strict_encode64(attachment)}</Att>))

    expect(described_class.resolve(doc.root, {})).to eq(attachment)
  end

  it "raises when an xop:Include names an attachment the message doesn't carry" do
    doc, attachments = described_class.parse(*described_class.build(envelope).to_h.values_at(:content_type, :body))

    expect { described_class.resolve(doc.at_xpath("//Att"), attachments) }.to raise_error(Mef::Client::Error, /missing MTOM attachment/)
  end
end
