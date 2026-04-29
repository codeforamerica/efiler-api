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
        error_messages: ack.css("ValidationErrorList ValidationErrorGrp ErrorMessageTxt").map(&:text)
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
