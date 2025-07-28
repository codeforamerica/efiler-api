require "nokogiri"

class SubmissionsStatus
  TRANSMITTED_STATUSES = ["Received", "Ready for Pickup", "Ready for Pick-Up", "Sent to State", "Received by State", "Rejected Acknowledgment Created"]
  READY_FOR_ACK_STATUSES = ["Denied by IRS", "Acknowledgement Received from State", "Acknowledgement Retrieved", "Notified"]

  def self.handle_submission_status_response(response)
    doc = Nokogiri::XML(response)
    groups_by_irs_submission_id = group_status_records_by_submission_id(doc)
    groups_by_irs_submission_id.transform_values do |xml_nodes|
      xml_node = xml_node_with_most_recent_submission_status(xml_nodes)
      status = status_from_xml_node(xml_node)
      submission_status_to_state(status)
    end
  end

  def self.group_status_records_by_submission_id(doc)
    # The service returns multiple status records for the each submission id. It looks like they are in reverse
    # chronological order (But are not properly date stamped), although we have seen examples where they are out of
    # order. Regardless, we return each submission ID's list of statuses in the order they are encountered in the XML
    doc.css("StatusRecordGrp").each_with_object({}) do |xml, groups_by_irs_submission_id|
      irs_submission_id = xml.css("SubmissionId").text.strip
      if groups_by_irs_submission_id[irs_submission_id]
        groups_by_irs_submission_id[irs_submission_id].append(xml)
      else
        groups_by_irs_submission_id[irs_submission_id] = [xml]
      end
    end
  end

  def self.xml_node_with_most_recent_submission_status(submission_status_xml_nodes)
    # We might see out-of-order statuses in the list, so search the list for more-progresses statuses first
    preferred_status_order = [READY_FOR_ACK_STATUSES, TRANSMITTED_STATUSES]
    preferred_status_order.each do |statuses_to_look_for|
      most_recent_status_node = submission_status_xml_nodes.find do |xml_node|
        statuses_to_look_for.include? status_from_xml_node(xml_node)
      end
      return most_recent_status_node if most_recent_status_node
    end
  end

  def self.status_from_xml_node(xml_node)
    xml_node&.css("SubmissionStatusTxt")&.text&.strip
  end

  def self.submission_status_to_state(status)
    if TRANSMITTED_STATUSES.include?(status)
      # no action required - the IRS are still working on it
      :transmitted
    elsif READY_FOR_ACK_STATUSES.include?(status)
      :ready_for_ack
    else
      :failed
    end
  end
end
