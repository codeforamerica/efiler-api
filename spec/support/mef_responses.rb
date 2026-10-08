# MeF responses shaped like the ones the IRS A2A Toolkit accepts, for stubbing MeF over WebMock.
module MefResponses
  SAML = "urn:oasis:names:tc:SAML:1.0:assertion"

  def self.saml_assertion(session_value = "session-value")
    %(<saml:Assertion xmlns:saml="#{SAML}" MajorVersion="1" MinorVersion="1" AssertionID="a-1" Issuer="mef" IssueInstant="2026-10-13T13:00:00Z">) +
      %(<saml:AttributeStatement><saml:Attribute AttributeName="SMSESSION" AttributeNamespace="mef"><saml:AttributeValue>#{session_value}</saml:AttributeValue></saml:Attribute></saml:AttributeStatement></saml:Assertion>)
  end

  def self.envelope(body, security: "", envelope_namespaces: "")
    %(<?xml version="1.0" encoding="UTF-8"?><soap:Envelope xmlns:soap="#{Mef::Client::Envelope::SOAP_ENV}"#{envelope_namespaces}><soap:Header>) +
      %(<wsse:Security xmlns:wsse="#{Mef::Client::Envelope::WSSE}">#{security}</wsse:Security></soap:Header><soap:Body>#{body}</soap:Body></soap:Envelope>)
  end

  # MeF sets JSESSIONID and a `dc` data-center cookie, each as its own Set-Cookie header.
  def self.login(cookie: "jsession-1", dc: "dcs", assertion: saml_assertion, envelope_namespaces: "")
    {
      status: 200,
      headers: {
        "Content-Type" => "text/xml; charset=utf-8",
        "Set-Cookie" => [
          cookie && "JSESSIONID=#{cookie}; Path=/; Secure; HttpOnly",
          dc && "dc=#{dc}; Path=/; Expires=Tue, 13 Oct 2026 14:15:00 GMT; Max-Age=900"
        ].compact.presence
      }.compact,
      body: envelope(%(<LoginResponse xmlns="#{Mef::Client::Envelope::MSI}"><StatusTxt>Success</StatusTxt></LoginResponse>), security: assertion, envelope_namespaces:)
    }
  end

  def self.logout
    {
      status: 200,
      headers: {"Content-Type" => "text/xml; charset=utf-8"},
      body: envelope(%(<LogoutResponse xmlns="#{Mef::Client::Envelope::MSI}"><StatusTxt>Success</StatusTxt></LogoutResponse>))
    }
  end

  # A transmitter response whose `attachment_element` carries a zip of `file_contents`.
  def self.transmitter(operation, attachment_element, file_contents, cookie: nil, assertion: "")
    zip = Zip::OutputStream.write_buffer { |out|
      out.put_next_entry("response.xml")
      out.write(file_contents)
    }.string
    body = %(<#{operation}Response xmlns="#{Mef::Client::Envelope::TRANSMITTER}">) +
      %(<#{attachment_element}><xop:Include xmlns:xop="#{Mef::Client::Mtom::XOP}" href="cid:attachment-1@mef"/></#{attachment_element}></#{operation}Response>)
    boundary = "uuid:response-boundary"
    multipart = "--#{boundary}\r\nContent-Id: <root@mef>\r\nContent-Type: application/xop+xml;charset=utf-8;type=\"text/xml\"\r\nContent-Transfer-Encoding: binary\r\n\r\n".b +
      envelope(body, security: assertion).b + "\r\n--#{boundary}\r\nContent-Id: <attachment-1@mef>\r\nContent-Type: application/octet-stream\r\nContent-Transfer-Encoding: binary\r\n\r\n".b +
      zip.b + "\r\n--#{boundary}--".b
    {
      status: 200,
      headers: {
        "Content-Type" => %(multipart/related;start="<root@mef>";type="application/xop+xml";boundary="#{boundary}";start-info="text/xml"),
        "Set-Cookie" => cookie && "JSESSIONID=#{cookie}; Path=/"
      }.compact,
      body: multipart
    }
  end

  def self.fault(fault_string, classification: nil, status: 500)
    detail = classification && %(<detail><ErrorExceptionDetail xmlns="#{Mef::Client::Envelope::MEF_HEADER}"><ErrorMessageTxt>#{fault_string}</ErrorMessageTxt><ErrorClassificationCd>#{classification}</ErrorClassificationCd><ErrorMessageCd>MEF-1</ErrorMessageCd></ErrorExceptionDetail></detail>)
    {
      status: status,
      headers: {"Content-Type" => "text/xml; charset=utf-8"},
      body: envelope(%(<soap:Fault><faultcode>soap:Server</faultcode><faultstring>#{fault_string}</faultstring>#{detail}</soap:Fault>))
    }
  end
end
