module Mef
  module Client
    # One MeF A2A session: Login, any number of transmitter operations, then Logout. The session
    # is carried by MeF's cookies (JSESSIONID, plus the `dc` data-center cookie) and by the SAML
    # assertion that Login returns, which every later request echoes.
    class Session
      HOSTS = {"test" => "https://la.alt.www4.irs.gov", "prod" => "https://la.www4.irs.gov"}
      TIMEOUT = 600 # seconds, matching the toolkit's transport.properties

      NAMESPACES = {"S" => Envelope::SOAP_ENV, "wsse" => Envelope::WSSE, "mefhdr" => Envelope::MEF_HEADER, "mtx" => Envelope::TRANSMITTER}
      # Login returns it; like the toolkit, a newer one in any later response replaces it.
      SAML_ASSERTION = "/S:Envelope/S:Header/wsse:Security/*[local-name()='Assertion' and " \
        "(namespace-uri()='urn:oasis:names:tc:SAML:1.0:assertion' or namespace-uri()='urn:oasis:names:tc:SAML:2.0:assertion')]"

      # The failures the toolkit path has always retried: MeF maintenance redirects, gateway
      # authentication hiccups, outages, and session-limit or session-cookie faults.
      RETRYABLE_HTTP_STATUSES = [302, 401, 403, 500, 503]
      RETRYABLE_FAULT_CLASSIFICATIONS = %w[SYSTEM_ERROR RESOURCE_UNAVAILABLE]
      RETRYABLE_FAULT_MESSAGES = [/Session limit reached/, /Cookie validation for session/]

      def self.open(credentials, release, connection: nil)
        session = new(credentials, release, connection:)
        session.login!
        begin
          yield session
        ensure
          begin
            session.logout!
          rescue => e
            # The operation's outcome stands: retrying a transmitted submission because Logout
            # failed would send it twice. MeF expires the session on its own.
            Rails.logger.warn("MeF Logout failed: #{e.class}")
          end
        end
      end

      def initialize(credentials, release, connection: nil)
        @credentials = credentials
        @envelope = Envelope.new(credentials, release)
        @connection = connection || Faraday.new(HOSTS.fetch(credentials.mef_env), request: {timeout: TIMEOUT, open_timeout: TIMEOUT})
        @cookies = {}
      end

      def login!
        doc = Signer.new(@credentials).sign(@envelope.login)
        post("/a2a/mef/Login", "Login", "text/xml; charset=utf-8", Envelope.serialize(doc))
        raise Error, "MeF Login response has no SAML assertion" if @saml_assertion.nil?
        raise Error, "MeF Login response set no JSESSIONID cookie" unless @cookies.key?("JSESSIONID")
      end

      def logout!
        post("/a2a/mef/Logout", "Logout", "text/xml; charset=utf-8", Envelope.serialize(@envelope.logout(@saml_assertion)))
      end

      # Each operation returns the XML document inside the response's attachment zip.
      def get_acks(submission_ids)
        transmitter("GetAcks", Requests.get_acks(submission_ids), "AcknowledgementListAttMTOM")
      end

      def get_submissions_status(submission_ids)
        transmitter("GetSubmissionsStatus", Requests.get_submissions_status(submission_ids), "StatusRecordListAttMTOM")
      end

      def send_submissions(submission_id, bundle, postmarked_at: Time.now)
        content_id = SecureRandom.uuid
        transmitter("SendSubmissions", Requests.send_submissions(submission_id, postmarked_at, content_id),
          "SubmissionRcptListAttMTOM", content_id => submission_container(submission_id, bundle))
      end

      private

      def transmitter(operation, body, attachment_element, attachments = {})
        message = Mtom.build(Envelope.serialize(@envelope.transmitter(@saml_assertion, operation:, body:)), attachments)
        doc, response_attachments = post("/a2a/mef/mtom/#{operation}", "mtom/#{operation}", message.content_type, message.body)
        element = doc.at_xpath("/S:Envelope/S:Body/mtx:#{operation}Response/mtx:#{attachment_element}", NAMESPACES)
        raise Error, "MeF #{operation} response has no #{attachment_element}" if element.nil?

        single_file_in_zip(Mtom.resolve(element, response_attachments))
      end

      # MeF takes a zip of submission zips and reads it as a stream, so, as the toolkit does, each
      # one is stored uncompressed with its size and CRC in the local header. Giving rubyzip the
      # size up front keeps it from writing a Zip64 placeholder header instead.
      def submission_container(submission_id, bundle)
        Zip::OutputStream.write_buffer do |zip|
          zip.put_next_entry(Zip::Entry.new(nil, "#{submission_id}.zip", compression_method: Zip::Entry::STORED, size: bundle.bytesize))
          zip.write(bundle)
        end.string
      end

      def single_file_in_zip(bytes)
        Zip::File.open_buffer(StringIO.new(bytes)) do |zip|
          raise Error, "MeF attachment zip holds #{zip.entries.size} files, expected 1" if zip.entries.size != 1

          return zip.read(zip.entries.first)
        end
      end

      def post(path, soap_action, content_type, body)
        headers = {
          "Content-Type" => content_type,
          "Accept" => "text/xml, multipart/related",
          "SOAPAction" => %("http://www.irs.gov/a2a/mef/#{soap_action}")
        }
        headers["Cookie"] = @cookies.map { |name, value| "#{name}=#{value}" }.join("; ") if @cookies.any?
        response = @connection.post(path, body, headers)
        remember_cookies(response.headers["set-cookie"])
        doc, attachments = parse(path, response)
        @saml_assertion = doc.at_xpath(SAML_ASSERTION, NAMESPACES) || @saml_assertion
        [doc, attachments]
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::SSLError => e
        raise MefService::RetryableError, "MeF #{path}: #{e.class}"
      end

      # Like the toolkit, keeps every cookie MeF sets, by name, ignoring attributes. Faraday joins
      # repeated Set-Cookie headers with ", ", which an Expires date can also contain.
      def remember_cookies(set_cookie)
        set_cookie.to_s.split(/,\s*(?=[^\s;,=]+=)/).each do |cookie|
          name, value = cookie.split(";", 2).first.split("=", 2).map(&:strip)
          @cookies[name] = value if name.present? && value
        end
      end

      def parse(path, response)
        doc, attachments = Mtom.parse(response.headers["content-type"], response.body)
        fault = doc.at_xpath("/S:Envelope/S:Body/S:Fault", NAMESPACES)
        raise_for_fault(path, response.status, fault) if fault
        raise_for_status(path, response.status) unless response.status == 200
        raise MefService::RetryableError, "MeF #{path}: unparseable response" if doc.root.nil?

        [doc, attachments]
      end

      def raise_for_fault(path, status, fault)
        detail = fault.at_xpath(".//mefhdr:ErrorExceptionDetail", NAMESPACES)
        classification = detail&.at_xpath("mefhdr:ErrorClassificationCd", NAMESPACES)&.text
        fault_string = fault.at_xpath("faultstring")&.text.to_s
        message = "MeF #{path} fault (HTTP #{status}, #{classification || "unclassified"}" \
          "#{detail&.at_xpath("mefhdr:ErrorMessageCd", NAMESPACES)&.text&.then { |code| ", #{code}" }}): " \
          "#{detail&.at_xpath("mefhdr:ErrorMessageTxt", NAMESPACES)&.text || fault_string}"

        retryable = RETRYABLE_FAULT_CLASSIFICATIONS.include?(classification) ||
          RETRYABLE_FAULT_MESSAGES.any? { |pattern| fault_string.match?(pattern) }
        raise(retryable ? MefService::RetryableError : Error, message)
      end

      def raise_for_status(path, status)
        raise(RETRYABLE_HTTP_STATUSES.include?(status) ? MefService::RetryableError : Error, "MeF #{path}: HTTP #{status}")
      end
    end
  end
end
