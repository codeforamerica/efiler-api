module Mef
  module Client
    # MTOM (multipart/related with XOP) framing, laid out as the toolkit's Metro stack writes it.
    # MeF's transmitter services use MTOM for every request and response, attachment or not.
    module Mtom
      XOP = "http://www.w3.org/2004/08/xop/include"

      Message = Data.define(:content_type, :body)

      # `attachments` maps each Content-ID that the envelope references with an xop:Include href
      # of "cid:<id>" to the attachment's bytes.
      def self.build(soap_xml, attachments = {})
        uuid = SecureRandom.uuid
        boundary = "uuid:#{uuid}"
        root_id = "<rootpart*#{uuid}@example.jaxws.sun.com>"

        body = +"".b
        body << part_header(boundary, root_id, %(application/xop+xml;charset=utf-8;type="text/xml")) << soap_xml.b
        attachments.each do |content_id, bytes|
          body << "\r\n".b << part_header(boundary, "<#{content_id}>", "application/octet-stream") << bytes.b
        end
        body << "\r\n--#{boundary}--".b

        Message.new(
          content_type: %(multipart/related;start="#{root_id}";type="application/xop+xml";boundary="#{boundary}";start-info="text/xml"),
          body: body
        )
      end

      # Returns the SOAP envelope and the attachments keyed by Content-ID (without angle brackets).
      # A plain text/xml response, as SOAP faults are, has no attachments.
      def self.parse(content_type, body)
        return [Nokogiri::XML(body), {}] unless content_type.to_s.downcase.start_with?("multipart/related")

        message = Mail::Message.new("Content-Type: #{content_type}\r\n\r\n".b + body.b)
        parts = message.parts.to_h { |part| [part.content_id.to_s.delete_prefix("<").delete_suffix(">"), part.body.decoded] }
        root_id = message.content_type_parameters["start"]&.delete_prefix("<")&.delete_suffix(">") || parts.keys.first
        root = parts.delete(root_id) or raise Error, "MTOM response has no root part #{root_id}"
        [Nokogiri::XML(root), parts]
      end

      # The bytes an element's xop:Include refers to.
      def self.resolve(element, attachments)
        content_id = element.at_xpath("xop:Include", "xop" => XOP)&.[]("href")&.delete_prefix("cid:")
        attachments.fetch(CGI.unescape(content_id.to_s)) { raise Error, "#{element.name} references a missing MTOM attachment" }
      end

      private_class_method def self.part_header(boundary, content_id, content_type)
        "--#{boundary}\r\nContent-ID: #{content_id}\r\nContent-Type: #{content_type}\r\nContent-Transfer-Encoding: binary\r\n\r\n".b
      end
    end
  end
end
