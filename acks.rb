require "nokogiri"

class Acks
  def self.handle_ack_response(response)
    doc = Nokogiri::XML(response)

    doc.css('AcknowledgementList Acknowledgement').to_h do |ack|
      irs_submission_id = ack.css("SubmissionId").text.strip
      status = ack.css("AcceptanceStatusTxt").text.strip.downcase

      status_code = if ["rejected", "r", "denied by irs"].include?(status)
                      :rejected
                    elsif ["accepted", "a"].include?(status)
                      :accepted
                    elsif ["exception"].include?(status)
                      :accepted_but_imperfect
                    else
                      :failed
                    end
      [irs_submission_id, status_code]
    end
  end

end