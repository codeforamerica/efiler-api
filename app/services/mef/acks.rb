class Mef::Acks
  def self.parse_acks_response(response)
    doc = Nokogiri::XML(response)

    results = {}

    doc.css("AcknowledgementList Acknowledgement").each do |ack|
      irs_submission_id = ack.css("SubmissionId").text.strip

      error_messages = ack.css("ValidationErrorList ValidationErrorGrp ErrorMessageTxt").map(&:text)

      status = case ack.css("AcceptanceStatusTxt").text.strip.downcase
      when "rejected", "r", "denied by irs"
        :rejected
      when "accepted", "a", "exception"
        :accepted
      else
        :failed
      end

      if results.key? irs_submission_id
        results[irs_submission_id][:status] = status  # take the most recent status, which will be last in the list
        results[irs_submission_id][:error_messages] += error_messages
      else
        results[irs_submission_id] = {status:, error_messages:}
      end
    end

    results.map do |irs_submission_id, parsed_acks|
      {
        irs_submission_id:,
        status: parsed_acks[:status],
        error_messages: parsed_acks[:error_messages].uniq
      }
    end
  end
end
