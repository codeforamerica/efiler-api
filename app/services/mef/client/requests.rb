module Mef
  module Client
    # Request elements for MeF's transmitter operations, namespaced as the toolkit writes them.
    module Requests
      def self.get_acks(submission_ids)
        operation("GetAcksRequest", submission_id_list(submission_ids))
      end

      def self.get_submissions_status(submission_ids)
        operation("GetSubmissionsStatusRequest", submission_id_list(submission_ids))
      end

      # The submissions themselves travel as the MTOM attachment `content_id`.
      def self.send_submissions(submission_id, postmarked_at, content_id)
        operation("SendSubmissionsRequest",
          "<ns2:SubmissionDataList><ns2:SubmissionData>" \
          "<ns2:SubmissionId>#{text(submission_id)}</ns2:SubmissionId>" \
          "<ns2:ElectronicPostmarkTs>#{postmarked_at.iso8601(3)}</ns2:ElectronicPostmarkTs>" \
          "</ns2:SubmissionData></ns2:SubmissionDataList>" +
          %(<ns2:SubmissionsAttMTOM><xop:Include xmlns:xop="#{Mtom::XOP}" href="cid:#{content_id}"/></ns2:SubmissionsAttMTOM>))
      end

      private_class_method def self.operation(element, content)
        %(<ns2:#{element} xmlns="#{Envelope::MEF_HEADER}" xmlns:ns2="#{Envelope::TRANSMITTER}" xmlns:xmime="http://www.w3.org/2005/05/xmlmime">#{content}</ns2:#{element}>)
      end

      private_class_method def self.submission_id_list(submission_ids)
        "<ns2:SubmissionIdList>#{submission_ids.map { |id| "<ns2:SubmissionId>#{text(id)}</ns2:SubmissionId>" }.join}</ns2:SubmissionIdList>"
      end

      private_class_method def self.text(value)
        value.to_s.encode(xml: :text)
      end
    end
  end
end
