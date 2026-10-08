module Mef
  module Client
    # Signs a Login envelope the way the toolkit's login_client_security_config.xml asks: an
    # X.509 BinarySecurityToken plus an RSA-SHA256 signature over the MeFHeader and the Body,
    # both exclusive-canonicalized.
    class Signer
      DS = "http://www.w3.org/2000/09/xmldsig#"
      EXC_C14N = "http://www.w3.org/2001/10/xml-exc-c14n#"
      RSA_SHA256 = "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"
      SHA256 = "http://www.w3.org/2001/04/xmlenc#sha256"
      X509V3 = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3"
      BASE64_BINARY = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary"
      TOKEN_ID = "X509Token"
      NAMESPACES = {"S" => Envelope::SOAP_ENV, "wsse" => Envelope::WSSE, "wsu" => Envelope::WSU, "mefhdr" => Envelope::MEF_HEADER, "ds" => DS}

      SIGNED_INFO_PREFIXES = %w[wsse S SOAP-ENV]
      HEADER_PREFIXES = %w[ns2 S SOAP-ENV]
      BODY_PREFIXES = %w[S SOAP-ENV ns2]

      def initialize(credentials)
        @credentials = credentials
      end

      def sign!(doc)
        security = doc.at_xpath("/S:Envelope/S:Header/wsse:Security", NAMESPACES)
        header = doc.at_xpath("/S:Envelope/S:Header/mefhdr:MeFHeader", NAMESPACES)
        body = doc.at_xpath("/S:Envelope/S:Body", NAMESPACES)

        security.add_child(binary_security_token)
        signature = security.add_child(signature_skeleton(reference(header, HEADER_PREFIXES), reference(body, BODY_PREFIXES))).first

        # SignedInfo is canonicalized in place, so the namespaces in scope are the ones MeF sees.
        signed_info = signature.at_xpath("ds:SignedInfo", NAMESPACES)
        signature_value = @credentials.private_key.sign(OpenSSL::Digest.new("SHA256"), canonicalize(signed_info, SIGNED_INFO_PREFIXES))
        signature.at_xpath("ds:SignatureValue", NAMESPACES).content = Base64.strict_encode64(signature_value)
        doc
      end

      private

      def binary_security_token
        %(<wsse:BinarySecurityToken xmlns:wsse="#{Envelope::WSSE}" xmlns:wsu="#{Envelope::WSU}" ) +
          %(EncodingType="#{BASE64_BINARY}" ValueType="#{X509V3}" wsu:Id="#{TOKEN_ID}">) +
          Base64.strict_encode64(@credentials.certificate.to_der) +
          %(</wsse:BinarySecurityToken>)
      end

      def reference(node, prefixes)
        digest = Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(canonicalize(node, prefixes)))
        %(<ds:Reference URI="##{node.attribute_with_ns("Id", Envelope::WSU).value}"><ds:Transforms><ds:Transform Algorithm="#{EXC_C14N}">) +
          %(<InclusiveNamespaces xmlns="#{EXC_C14N}" PrefixList="#{prefixes.join(" ")}"/></ds:Transform></ds:Transforms>) +
          %(<ds:DigestMethod Algorithm="#{SHA256}"/><ds:DigestValue>#{digest}</ds:DigestValue></ds:Reference>)
      end

      def signature_skeleton(*references)
        %(<ds:Signature xmlns:ds="#{DS}" Id="s"><ds:SignedInfo>) +
          %(<ds:CanonicalizationMethod Algorithm="#{EXC_C14N}"><InclusiveNamespaces xmlns="#{EXC_C14N}" PrefixList="#{SIGNED_INFO_PREFIXES.join(" ")}"/></ds:CanonicalizationMethod>) +
          %(<ds:SignatureMethod Algorithm="#{RSA_SHA256}"/>#{references.join}</ds:SignedInfo>) +
          %(<ds:SignatureValue/><ds:KeyInfo><wsse:SecurityTokenReference xmlns:wsse="#{Envelope::WSSE}" xmlns:wsu="#{Envelope::WSU}" wsu:Id="#{Envelope.wsu_id}">) +
          %(<wsse:Reference URI="##{TOKEN_ID}" ValueType="#{X509V3}"/></wsse:SecurityTokenReference></ds:KeyInfo></ds:Signature>)
      end

      def canonicalize(node, prefixes)
        node.canonicalize(Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0, prefixes)
      end
    end
  end
end
