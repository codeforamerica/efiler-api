# MeF responses shaped like the ones ATS returns, with synthetic values, for stubbing MeF over
# WebMock. MeF's servers frame MTOM the way Apache Axis2 does, put small attachments inline as
# base64, and return a SAML assertion signed by the IRS gateway.
module MefResponses
  SAML = "urn:oasis:names:tc:SAML:1.0:assertion"
  DS = "http://www.w3.org/2000/09/xmldsig#"
  EXC_C14N = "http://www.w3.org/2001/10/xml-exc-c14n#"
  ENVELOPED_SIGNATURE = "http://www.w3.org/2000/09/xmldsig#enveloped-signature"
  GATEWAY = "http://www.forumsys.com/sentry"

  def self.gateway_key
    @gateway_key ||= OpenSSL::PKey::RSA.new(2048)
  end

  def self.gateway_certificate
    @gateway_certificate ||= OpenSSL::X509::Certificate.new.tap do |cert|
      cert.version = 2
      cert.serial = 1
      cert.subject = cert.issuer = OpenSSL::X509::Name.parse("/CN=mef-test-gateway")
      cert.public_key = gateway_key.public_key
      cert.not_before = Time.now - 60
      cert.not_after = Time.now + 3600
      cert.sign(gateway_key, OpenSSL::Digest.new("SHA256"))
    end
  end

  # A SAML 1.0 assertion carrying an enveloped signature by the gateway.
  def self.saml_assertion(session_value = "session-value")
    id = "id-#{SecureRandom.hex(16)}"
    subject = %(<saml:Subject><saml:NameIdentifier Format="urn:oasis:names:tc:SAML:1.1:nameid-format:X509SubjectName">UID=12345678</saml:NameIdentifier>) +
      %(<saml:SubjectConfirmation><saml:ConfirmationMethod>urn:oasis:names:tc:SAML:1.0:cm:sender-vouches</saml:ConfirmationMethod></saml:SubjectConfirmation></saml:Subject>)
    doc = Nokogiri::XML(
      %(<saml:Assertion xmlns:saml="#{SAML}" AssertionID="#{id}" IssueInstant="2026-10-13T23:17:21.422Z" Issuer="#{GATEWAY}" MajorVersion="1" MinorVersion="1">) +
      %(<saml:Conditions NotBefore="2026-10-13T23:17:21.422Z" NotOnOrAfter="2026-10-14T09:17:21.422Z"/>) +
      %(<saml:AuthenticationStatement AuthenticationInstant="2026-10-13T23:17:21.422Z" AuthenticationMethod="urn:oasis:names:tc:SAML:1.0:am:password">#{subject}</saml:AuthenticationStatement>) +
      %(<saml:AttributeStatement>#{subject}<saml:Attribute AttributeName="SMSESSION" AttributeNamespace="#{GATEWAY}"><saml:AttributeValue>#{session_value}</saml:AttributeValue></saml:Attribute></saml:AttributeStatement>) +
      %(</saml:Assertion>)
    )
    assertion = doc.root
    digest = Base64.strict_encode64(OpenSSL::Digest.digest("SHA256", assertion.canonicalize(Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0)))
    signature = assertion.add_child(
      %(<ds:Signature xmlns:ds="#{DS}"><ds:SignedInfo><ds:CanonicalizationMethod Algorithm="#{EXC_C14N}"/>) +
      %(<ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>) +
      %(<ds:Reference URI="##{id}"><ds:Transforms><ds:Transform Algorithm="#{ENVELOPED_SIGNATURE}"/><ds:Transform Algorithm="#{EXC_C14N}"/></ds:Transforms>) +
      %(<ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/><ds:DigestValue>#{digest}</ds:DigestValue></ds:Reference></ds:SignedInfo>) +
      %(<ds:SignatureValue/><ds:KeyInfo><ds:X509Data><ds:X509Certificate>#{Base64.encode64(gateway_certificate.to_der)}</ds:X509Certificate></ds:X509Data></ds:KeyInfo></ds:Signature>)
    ).first
    signed_info = signature.at_xpath("ds:SignedInfo", "ds" => DS).canonicalize(Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0)
    # Base64 with line breaks, as the gateway writes it.
    signature.at_xpath("ds:SignatureValue", "ds" => DS).content = "\n" + Base64.encode64(gateway_key.sign(OpenSSL::Digest.new("SHA256"), signed_info))
    assertion.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
  end

  # Whether an assertion's enveloped signature verifies against the gateway certificate. Removes
  # the signature from `assertion`'s document, as the enveloped-signature transform does.
  def self.saml_signature_valid?(assertion)
    ds = {"ds" => DS}
    signature = assertion.at_xpath("ds:Signature", ds)
    signed_info = signature.at_xpath("ds:SignedInfo", ds).canonicalize(Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0)
    signature_value = Base64.decode64(signature.at_xpath("ds:SignatureValue", ds).text)
    expected_digest = signature.at_xpath(".//ds:DigestValue", ds).text
    signature.unlink
    digest = Base64.strict_encode64(OpenSSL::Digest.digest("SHA256", assertion.canonicalize(Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0)))
    digest == expected_digest && gateway_certificate.public_key.verify(OpenSSL::Digest.new("SHA256"), signature_value, signed_info)
  end

  def self.mef_header(action, session_key_cd: "Y")
    %(<ns1:MeFHeader xmlns:ns1="#{Mef::Client::Envelope::MEF_HEADER}"><ns1:MessageID>123452026286responsex</ns1:MessageID>) +
      %(<ns1:RelatesTo>123452026286requestxx</ns1:RelatesTo><ns1:Action>#{action}</ns1:Action><ns1:MessageTs>2026-10-13T16:17:21-07:00</ns1:MessageTs>) +
      %(<ns1:ETIN>12345</ns1:ETIN><ns1:SessionKeyCd>#{session_key_cd}</ns1:SessionKeyCd><ns1:TestCd>T</ns1:TestCd><ns1:AppSysID>12345678</ns1:AppSysID>) +
      %(<ns1:WSDLVersionNum>10.A</ns1:WSDLVersionNum><ns1:ClientSoftwareTxt>org.codeforamerica.gyr.efiler</ns1:ClientSoftwareTxt></ns1:MeFHeader>)
  end

  def self.security(assertion)
    %(<wsse:Security xmlns:wsse="#{Mef::Client::Envelope::WSSE}">) +
      %(<wsu:Timestamp xmlns:wsu="#{Mef::Client::Envelope::WSU}" wsu:Id="id-timestamp"><wsu:Created>2026-10-13T23:17:21.425Z</wsu:Created><wsu:Expires>2026-10-14T09:17:21.425Z</wsu:Expires></wsu:Timestamp>) +
      %(<wsse:UsernameToken xmlns:wsu="#{Mef::Client::Envelope::WSU}" wsu:Id="id-username"><wsse:Username>12345678</wsse:Username></wsse:UsernameToken>) +
      %(#{assertion}</wsse:Security>)
  end

  def self.envelope(body, header: "", envelope_namespaces: "")
    %(<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="#{Mef::Client::Envelope::SOAP_ENV}"#{envelope_namespaces}>) +
      %(<soapenv:Header>#{header}</soapenv:Header><soapenv:Body>#{body}</soapenv:Body></soapenv:Envelope>)
  end

  # Axis2's MTOM framing: the root part, then any separate attachment parts.
  def self.mtom(soap, attachments = {})
    boundary = "MIMEBoundary_#{SecureRandom.hex(24)}"
    root_id = "0.#{SecureRandom.hex(24)}@apache.org"
    body = +"--#{boundary}\r\nContent-Type: application/xop+xml; charset=\"UTF-8\"; type=\"text/xml\"\r\nContent-Transfer-Encoding: binary\r\nContent-ID: <#{root_id}>\r\n\r\n".b
    body << soap.b << "\r\n".b
    attachments.each do |content_id, bytes|
      body << "--#{boundary}\r\nContent-Type: application/octet-stream\r\nContent-Transfer-Encoding: binary\r\nContent-ID: <#{content_id}>\r\n\r\n".b << bytes.b << "\r\n".b
    end
    body << "--#{boundary}--\r\n".b
    [%(multipart/related; boundary="#{boundary}"; type="application/xop+xml"; start="<#{root_id}>"; start-info="text/xml"), body]
  end

  def self.cookies(jsession: "jsession-1", dc: "dcd", jsession_expired: false)
    jsession_cookie = jsession && "JSESSIONID=#{jsession}; path=/a2a; secure; HttpOnly#{"; Expires=Thu, 01-Jan-1970 00:00:00 GMT" if jsession_expired}"
    dc_cookie = dc && "dc=#{dc}; Path=/; Version=1; Secure; Httponly; Max-Age=900"
    [jsession_cookie, dc_cookie].compact.presence
  end

  def self.login(cookie: "jsession-1", dc: "dcd", assertion: saml_assertion, envelope_namespaces: "")
    {
      status: 200,
      headers: {"Content-Type" => "text/xml;charset=utf-8", "Set-Cookie" => cookies(jsession: cookie, dc:)}.compact,
      body: envelope(%(<wn1:LoginResponse xmlns:wn1="#{Mef::Client::Envelope::MSI}"><wn1:StatusTxt>session counter updated</wn1:StatusTxt></wn1:LoginResponse>),
        header: mef_header("http://www.irs.gov/a2a/mef/Login") + security(assertion), envelope_namespaces:)
    }
  end

  def self.logout
    {
      status: 200,
      headers: {"Content-Type" => "text/xml;charset=utf-8", "Set-Cookie" => cookies(jsession: "jsession-1", jsession_expired: true)},
      body: envelope(%(<wn1:LogoutResponse xmlns:wn1="#{Mef::Client::Envelope::MSI}"><wn1:StatusTxt>Session counter decremented</wn1:StatusTxt></wn1:LogoutResponse>),
        header: mef_header("http://www.irs.gov/a2a/mef/Logout", session_key_cd: "N"))
    }
  end

  # A transmitter response whose `attachment_element` carries a zip of `file_contents`, inline as
  # MeF sends it, or as a separate xop:Include'd part.
  def self.transmitter(operation, attachment_element, file_contents, cookie: nil, assertion: saml_assertion, inline: true)
    zip = Zip::OutputStream.write_buffer { |out|
      out.put_next_entry("123452026286response.xml")
      out.write(file_contents)
    }.string
    attachment = inline ? Base64.strict_encode64(zip) : %(<xop:Include xmlns:xop="#{Mef::Client::Mtom::XOP}" href="cid:1.attachment@apache.org"/>)
    soap = envelope(%(<#{operation}Response xmlns="#{Mef::Client::Envelope::TRANSMITTER}"><#{attachment_element}>#{attachment}</#{attachment_element}></#{operation}Response>),
      header: mef_header("http://localhost:9080/a2a/mef/mtom/#{operation}") + security(assertion))
    content_type, body = mtom(soap, inline ? {} : {"1.attachment@apache.org" => zip})
    {status: 200, headers: {"Content-Type" => content_type, "Set-Cookie" => cookies(jsession: cookie, dc: nil)}.compact, body:}
  end

  # A typed MeF fault carries its message in ErrorExceptionDetail under a generic faultstring;
  # an untyped one, as the gateway raises, carries it in faultstring. MeF frames transmitter
  # faults as MTOM.
  def self.fault(message, classification: nil, code: "MEF00005", multipart: true, status: 500)
    detail = classification && %(<detail><ns2:ErrorExceptionDetail xmlns:ns2="#{Mef::Client::Envelope::MEF_HEADER}" xmlns="#{Mef::Client::Envelope::TRANSMITTER}">) +
      %(<ns2:ErrorMessageTxt>#{message}</ns2:ErrorMessageTxt><ns2:ErrorClassificationCd>#{classification}</ns2:ErrorClassificationCd><ns2:ErrorMessageCd>#{code}</ns2:ErrorMessageCd></ns2:ErrorExceptionDetail></detail>)
    soap = envelope(%(<soapenv:Fault><faultcode>soapenv:Server</faultcode><faultstring>#{classification ? "ErrorExceptionDetail" : message}</faultstring>#{detail}</soapenv:Fault>))
    content_type, body = multipart ? mtom(soap) : ["text/xml;charset=utf-8", soap]
    {status:, headers: {"Content-Type" => content_type}, body:}
  end
end
