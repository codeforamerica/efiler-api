class Mef::Acks
  def self.parse_acks_response(response)
    doc = Nokogiri::XML(response)
    results = {}

    doc.css("AcknowledgementList Acknowledgement").each do |ack|
      irs_submission_id = ack.css("SubmissionId").text.strip
      # MeF lists acks oldest-first. Multiple acks for one submission_id only
      # arise from resubmission attempts (rejected as non-unique), so the first
      # ack carries the original submission's outcome.
      next if results.key?(irs_submission_id)

      results[irs_submission_id] = {
        irs_submission_id:,
        status: status_code(ack),
        errors: ack.css("ValidationErrorList ValidationErrorGrp").map do |grp|
          {
            code: grp.at_css("RuleNum")&.text,
            category: grp.at_css("ErrorCategoryCd")&.text,
            severity: grp.at_css("SeverityCd")&.text,
            message: grp.at_css("ErrorMessageTxt")&.text,
            field_value: grp.at_css("FieldValueTxt")&.text.presence,
            xpath: grp.at_css("XpathContentTxt")&.text,
            document_id: grp.at_css("DocumentId")&.text
          }
        end
      }
    end

    results.values
  end

  def self.status_code(ack)
    case ack.css("AcceptanceStatusTxt").text.strip.downcase
    when "rejected", "r", "denied by irs"
      :rejected
    when "accepted", "a", "exception"
      :accepted
    else
      :failed
    end
  end
end
