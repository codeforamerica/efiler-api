module Mef
  module Client
    # SOAP envelopes laid out as the IRS A2A Toolkit (Metro/XWSS) writes them, down to the
    # namespace prefixes and the Action quirk.
    module Envelope
      SOAP_ENV = "http://schemas.xmlsoap.org/soap/envelope/"
      WSSE = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
      WSU = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
      MEF_HEADER = "http://www.irs.gov/a2a/mef/MeFHeader.xsd"
      MSI = "http://www.irs.gov/a2a/mef/MeFMSIServices.xsd"
      TRANSMITTER = "http://www.irs.gov/a2a/mef/MeFTransmitterServiceMTOM.xsd"

      WSDL_VERSION = "10.9"
      CLIENT_SOFTWARE = "org.codeforamerica.gyr.efiler"
      TIMESTAMP_TTL = 5.minutes

      # The toolkit fills Action from the WSDL's soapAction for MSI services but from the WSDL's
      # placeholder soap:address for MTOM ones, and MeF accepts both.
      MSI_ACTION = "http://www.irs.gov/a2a/mef/%s"
      TRANSMITTER_ACTION = "http://localhost:9080/a2a/mef/mtom/%s"

      def self.login(credentials)
        header_id = wsu_id
        body_id = wsu_id
        Nokogiri::XML(<<~XML.delete("\n"))
          <S:Envelope xmlns:S="#{SOAP_ENV}" xmlns:SOAP-ENV="#{SOAP_ENV}">
          <S:Header>
          <wsse:Security xmlns:wsse="#{WSSE}" S:mustUnderstand="1"/>
          #{mef_header(credentials, action: format(MSI_ACTION, "Login"), session_key_cd: "Y", operation_namespace: MSI, wsu_id: header_id)}
          </S:Header>
          <S:Body xmlns:wsu="#{WSU}" wsu:Id="#{body_id}">
          <ns2:LoginRequest xmlns="#{MEF_HEADER}" xmlns:ns2="#{MSI}"/>
          </S:Body>
          </S:Envelope>
        XML
      end

      # Never reformat: the Login signature covers the exact bytes of the MeFHeader and Body.
      def self.serialize(doc)
        doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
      end

      def self.logout(credentials, saml_assertion)
        session(credentials, saml_assertion,
          action: format(MSI_ACTION, "Logout"),
          session_key_cd: "N",
          operation_namespace: MSI,
          body: %(<ns2:LogoutRequest xmlns="#{MEF_HEADER}" xmlns:ns2="#{MSI}"/>))
      end

      # `body` is the operation's request element, written with the `ns2` prefix for TRANSMITTER.
      def self.transmitter(credentials, saml_assertion, operation:, body:)
        session(credentials, saml_assertion,
          action: format(TRANSMITTER_ACTION, operation),
          session_key_cd: "Y",
          operation_namespace: TRANSMITTER,
          body: body)
      end

      private_class_method def self.session(credentials, saml_assertion, action:, session_key_cd:, operation_namespace:, body:)
        now = Time.now.utc
        doc = Nokogiri::XML(<<~XML.delete("\n"))
          <S:Envelope xmlns:S="#{SOAP_ENV}" xmlns:SOAP-ENV="#{SOAP_ENV}">
          <S:Header>
          <wsse:Security xmlns:wsse="#{WSSE}" S:mustUnderstand="1">
          <wsu:Timestamp xmlns:wsu="#{WSU}" wsu:Id="#{wsu_id}">
          <wsu:Created>#{now.iso8601}</wsu:Created>
          <wsu:Expires>#{(now + TIMESTAMP_TTL).iso8601}</wsu:Expires>
          </wsu:Timestamp>
          <wsse:UsernameToken xmlns:wsu="#{WSU}" wsu:Id="#{wsu_id}">
          <wsse:Username>#{text(credentials.app_sys_id)}</wsse:Username>
          </wsse:UsernameToken>
          </wsse:Security>
          #{mef_header(credentials, action:, session_key_cd:, operation_namespace:)}
          </S:Header>
          <S:Body>#{body}</S:Body>
          </S:Envelope>
        XML
        doc.at_xpath("//wsse:Security", "wsse" => WSSE).add_child(saml_assertion.dup)
        doc
      end

      private_class_method def self.mef_header(credentials, action:, session_key_cd:, operation_namespace:, wsu_id: nil)
        id_attributes = wsu_id ? %( xmlns:wsu="#{WSU}" wsu:Id="#{wsu_id}") : ""
        <<~XML.delete("\n")
          <MeFHeader xmlns="#{MEF_HEADER}" xmlns:ns2="#{operation_namespace}"#{id_attributes}>
          <MessageID>#{message_id(credentials.etin)}</MessageID>
          <Action>#{action}</Action>
          <MessageTs>#{Time.now.iso8601}</MessageTs>
          <ETIN>#{text(credentials.etin)}</ETIN>
          <SessionKeyCd>#{session_key_cd}</SessionKeyCd>
          <TestCd>#{credentials.test_cd}</TestCd>
          <AppSysID>#{text(credentials.app_sys_id)}</AppSysID>
          <WSDLVersionNum>#{WSDL_VERSION}</WSDLVersionNum>
          <ClientSoftwareTxt>#{CLIENT_SOFTWARE}</ClientSoftwareTxt>
          </MeFHeader>
        XML
      end

      # ETIN + ccyyddd + 8 lowercase alphanumerics, per MeFHeader.xsd's HeaderMessageIdType.
      private_class_method def self.message_id(etin)
        "#{etin}#{Time.now.strftime("%Y%j")}#{SecureRandom.alphanumeric(8, chars: [*"a".."z", *"0".."9"])}"
      end

      def self.wsu_id
        "XWSSGID-#{SecureRandom.random_number(10**22)}"
      end

      private_class_method def self.text(value)
        value.to_s.encode(xml: :text)
      end
    end
  end
end
