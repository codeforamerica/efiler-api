module Mef
  module Client
    # Signs a Login envelope the way the toolkit's login_client_security_config.xml asks: an
    # X.509 BinarySecurityToken plus an RSA-SHA256 signature over the MeFHeader and the Body,
    # both exclusive-canonicalized with the toolkit's inclusive prefix lists.
    #
    # The signer gem writes InclusiveNamespaces with an `ec:` prefix where the toolkit uses a
    # default namespace; the two are equivalent XML-DSig.
    class Signer
      DS = "http://www.w3.org/2000/09/xmldsig#"
      EXC_C14N = "http://www.w3.org/2001/10/xml-exc-c14n#"
      TOKEN_ID = "X509Token"
      NAMESPACES = {"S" => Envelope::SOAP_ENV, "wsse" => Envelope::WSSE, "wsu" => Envelope::WSU, "mefhdr" => Envelope::MEF_HEADER, "ds" => DS}

      SIGNED_INFO_PREFIXES = %w[wsse S SOAP-ENV]
      HEADER_PREFIXES = %w[ns2 S SOAP-ENV]
      BODY_PREFIXES = %w[S SOAP-ENV ns2]

      def initialize(credentials)
        @credentials = credentials
      end

      # Returns a signed copy of `doc`.
      def sign(doc)
        signer = ::Signer.new(Envelope.serialize(doc), noblanks: false)
        signer.cert = @credentials.certificate
        signer.private_key = @credentials.private_key
        signer.digest_algorithm = :sha256
        signer.signature_digest_algorithm = :sha256
        signer.security_token_id = TOKEN_ID
        signer.ds_namespace_prefix = "ds"

        signed = signer.document
        signer.digest!(signed.at_xpath("/S:Envelope/S:Header/mefhdr:MeFHeader", NAMESPACES), inclusive_namespaces: HEADER_PREFIXES)
        signer.digest!(signed.at_xpath("/S:Envelope/S:Body", NAMESPACES), inclusive_namespaces: BODY_PREFIXES)
        signer.sign!(security_token: true, inclusive_namespaces: SIGNED_INFO_PREFIXES)

        # Unsigned identifiers the toolkit also writes; nothing references them.
        signed.at_xpath("//ds:Signature", NAMESPACES)["Id"] = "s"
        reference = signed.at_xpath("//ds:KeyInfo/wsse:SecurityTokenReference", NAMESPACES)
        reference.add_namespace_definition("wsu", Envelope::WSU)
        reference["wsu:Id"] = Envelope.wsu_id
        signed
      end
    end
  end
end
