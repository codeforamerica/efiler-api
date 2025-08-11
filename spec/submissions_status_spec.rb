require 'spec_helper'
require './submissions_status'

RSpec.describe SubmissionsStatus do
  let(:multiple_submissions_statuses_xml) do
    <<~XML
      <?xml version='1.0' encoding='UTF-8'?>
      <StatusRecordList xmlns="http://www.irs.gov/efile" xmlns:efile="http://www.irs.gov/efile">
          <Cnt>4</Cnt>
          <StatusRecordGrp>
              <SubmissionId>4414662024003wte794o</SubmissionId>
              <SubmissionStatusTxt>Received by State</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-04</SubmsnStatusAcknowledgementDt>
          </StatusRecordGrp>
          <StatusRecordGrp>
              <SubmissionId>abcdefghijklmnopqrst</SubmissionId>
              <SubmissionStatusTxt>Received by State</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-04</SubmsnStatusAcknowledgementDt>
          </StatusRecordGrp>
          <StatusRecordGrp>
              <SubmissionId>abcdefghijklmnopqrst</SubmissionId>
              <SubmissionStatusTxt>Sent to State</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-04</SubmsnStatusAcknowledgementDt>
          </StatusRecordGrp>
          <StatusRecordGrp>
              <SubmissionId>4414662024003wte794o</SubmissionId>
              <SubmissionStatusTxt>Sent to State</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-04</SubmsnStatusAcknowledgementDt>
          </StatusRecordGrp>
          <StatusRecordGrp>
              <SubmissionId>abcdefghijklmnopqrst</SubmissionId>
              <SubmissionStatusTxt>Ready for Pick-Up</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-03</SubmsnStatusAcknowledgementDt>
          </StatusRecordGrp>
          <StatusRecordGrp>
              <SubmissionId>abcdefghijklmnopqrst</SubmissionId>
              <SubmissionStatusTxt>Received</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-03</SubmsnStatusAcknowledgementDt>
          </StatusRecordGrp>
          <StatusRecordGrp>
              <SubmissionId>4414662024003wte794o</SubmissionId>
              <SubmissionStatusTxt>Ready for Pick-Up</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-03</SubmsnStatusAcknowledgementDt>
          </StatusRecordGrp>
          <StatusRecordGrp>
              <SubmissionId>4414662024003wte794o</SubmissionId>
              <SubmissionStatusTxt>Received</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-03</SubmsnStatusAcknowledgementDt>
          </StatusRecordGrp>
      </StatusRecordList>
      XML
  end

  describe '.handle_submission_status_response' do
    it 'returns the right thing' do
      expect(described_class.handle_submission_status_response(multiple_submissions_statuses_xml))
        .to eq({ '4414662024003wte794o' => :transmitted, 'abcdefghijklmnopqrst' => :transmitted })
    end
  end

  describe '.group_status_records_by_submission_id' do
    it 'groups statuses by submission_id, preserving their order' do
      result = described_class.group_status_records_by_submission_id(Nokogiri::XML(multiple_submissions_statuses_xml))
      submission_ids = %w[4414662024003wte794o abcdefghijklmnopqrst]
      expect(result.keys).to match_array submission_ids
      submission_ids.each do |submission_id|
        expect(result[submission_id].length).to eq 4
        expect(result[submission_id].first.css('SubmissionStatusTxt').text).to eq 'Received by State'
        expect(result[submission_id].last.css('SubmissionStatusTxt').text).to eq 'Received'
      end
    end
  end

  describe '.xml_node_with_most_recent_submission_status' do
    it 'gets the most recent xml node indicating a transmitted state in a correctly ordered list of statuses' do
      xml_nodes = [
        Nokogiri::XML(
          <<~XML
            <StatusRecordGrp>
              <SubmissionId>4414662024003wte794o</SubmissionId>
              <SubmissionStatusTxt>Received by State</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-04</SubmsnStatusAcknowledgementDt>
            </StatusRecordGrp>
          XML
        ),
        Nokogiri::XML(
          <<~XML
            <StatusRecordGrp>
              <SubmissionId>4414662024003wte794o</SubmissionId>
              <SubmissionStatusTxt>Sent to State</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-04</SubmsnStatusAcknowledgementDt>
            </StatusRecordGrp>
          XML
        ),
        Nokogiri::XML(
          <<~XML
            <StatusRecordGrp>
              <SubmissionId>4414662024003wte794o</SubmissionId>
              <SubmissionStatusTxt>Ready for Pick-Up</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-03</SubmsnStatusAcknowledgementDt>
            </StatusRecordGrp>
          XML
        ),
        Nokogiri::XML(
          <<~XML
            <StatusRecordGrp>
              <SubmissionId>4414662024003wte794o</SubmissionId>
              <SubmissionStatusTxt>Received</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-03</SubmsnStatusAcknowledgementDt>
            </StatusRecordGrp>
          XML
        )
      ]
      xml_node = described_class.xml_node_with_most_recent_submission_status(xml_nodes)
      expect(xml_node.css('SubmissionStatusTxt').text).to eq 'Received by State'
    end

    it 'gets the most recent xml node indicating a ready-for-ack state in a correctly ordered list of statuses' do
      xml_nodes = [
        Nokogiri::XML(
          <<~XML
            <StatusRecordGrp>
              <SubmissionId>4414662024003wte794o</SubmissionId>
              <SubmissionStatusTxt>Acknowledgement Received from State</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-04</SubmsnStatusAcknowledgementDt>
            </StatusRecordGrp>
          XML
        ),
        Nokogiri::XML(
          <<~XML
            <StatusRecordGrp>
              <SubmissionId>4414662024003wte794o</SubmissionId>
              <SubmissionStatusTxt>Received by State</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-04</SubmsnStatusAcknowledgementDt>
            </StatusRecordGrp>
          XML
        ),
        Nokogiri::XML(
          <<~XML
            <StatusRecordGrp>
              <SubmissionId>4414662024003wte794o</SubmissionId>
              <SubmissionStatusTxt>Sent to State</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-04</SubmsnStatusAcknowledgementDt>
            </StatusRecordGrp>
          XML
        ),
        Nokogiri::XML(
          <<~XML
            <StatusRecordGrp>
              <SubmissionId>4414662024003wte794o</SubmissionId>
              <SubmissionStatusTxt>Ready for Pick-Up</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-03</SubmsnStatusAcknowledgementDt>
            </StatusRecordGrp>
          XML
        ),
        Nokogiri::XML(
          <<~XML
            <StatusRecordGrp>
              <SubmissionId>4414662024003wte794o</SubmissionId>
              <SubmissionStatusTxt>Received</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-03</SubmsnStatusAcknowledgementDt>
            </StatusRecordGrp>
          XML
        )
      ]
      xml_node = described_class.xml_node_with_most_recent_submission_status(xml_nodes)
      expect(xml_node.css('SubmissionStatusTxt').text).to eq 'Acknowledgement Received from State'
    end

    it 'gets the most recent xml node indicating a ready-for-ack state in an incorrectly ordered list of statuses' do
      xml_nodes = [
        Nokogiri::XML(
          <<~XML
            <StatusRecordGrp>
              <SubmissionId>4414662024003wte794o</SubmissionId>
              <SubmissionStatusTxt>Received by State</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-04</SubmsnStatusAcknowledgementDt>
            </StatusRecordGrp>
          XML
        ),
        Nokogiri::XML(
          <<~XML
            <StatusRecordGrp>
            <SubmissionId>4414662024003wte794o</SubmissionId>
            <SubmissionStatusTxt>Acknowledgement Received from State</SubmissionStatusTxt>
            <SubmsnStatusAcknowledgementDt>2024-01-04</SubmsnStatusAcknowledgementDt>
            </StatusRecordGrp>
          XML
        ),
        Nokogiri::XML(
          <<~XML
            <StatusRecordGrp>
            <SubmissionId>4414662024003wte794o</SubmissionId>
            <SubmissionStatusTxt>Sent to State</SubmissionStatusTxt>
            <SubmsnStatusAcknowledgementDt>2024-01-04</SubmsnStatusAcknowledgementDt>
            </StatusRecordGrp>
          XML
        ),
        Nokogiri::XML(
          <<~XML
            <StatusRecordGrp>
            <SubmissionId>4414662024003wte794o</SubmissionId>
            <SubmissionStatusTxt>Ready for Pick-Up</SubmissionStatusTxt>
            <SubmsnStatusAcknowledgementDt>2024-01-03</SubmsnStatusAcknowledgementDt>
            </StatusRecordGrp>
          XML
        ),
        Nokogiri::XML(
          <<~XML
            <StatusRecordGrp>
            <SubmissionId>4414662024003wte794o</SubmissionId>
            <SubmissionStatusTxt>Received</SubmissionStatusTxt>
            <SubmsnStatusAcknowledgementDt>2024-01-03</SubmsnStatusAcknowledgementDt>
            </StatusRecordGrp>
          XML
        )
      ]
      xml_node = described_class.xml_node_with_most_recent_submission_status(xml_nodes)
      expect(xml_node.css('SubmissionStatusTxt').text).to eq 'Acknowledgement Received from State'
    end
  end

  describe '.status_from_xml_node' do
    it 'gets the status from the correct node' do
      xml_node = Nokogiri::XML(
        <<~XML
          <StatusRecordGrp>
              <SubmissionId>4414662024003wte794o</SubmissionId>
              <SubmissionStatusTxt>Acknowledgement Received from State</SubmissionStatusTxt>
              <SubmsnStatusAcknowledgementDt>2024-01-04</SubmsnStatusAcknowledgementDt>
          </StatusRecordGrp>
        XML
      )

      expect(described_class.status_from_xml_node(xml_node)).to eq 'Acknowledgement Received from State'
    end
  end

  describe '.submission_status_to_state' do
    it 'interprets transmitted statuses successfully' do
      described_class::TRANSMITTED_STATUSES.each do |status|
        expect(described_class.submission_status_to_state(status)).to eq :transmitted
      end
    end

    it 'interprets ready_for_ack statuses successfully' do
      described_class::READY_FOR_ACK_STATUSES.each do |status|
        expect(described_class.submission_status_to_state(status)).to eq :ready_for_ack
      end
    end

    it 'interprets unknown states as failed' do
      expect(described_class.submission_status_to_state('My dog ate it')).to eq :failed
    end
  end
end
