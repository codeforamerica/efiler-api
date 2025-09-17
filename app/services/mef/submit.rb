class Mef::Submit
  def self.send_submission_bundle(mef_credentials, submission_bundle_filename, submission_bundle_contents_base64)
    Dir.mktmpdir do |dir|
      submission_path = File.join(dir, submission_bundle_filename)
      File.binwrite(submission_path, Base64.strict_decode64(submission_bundle_contents_base64))
      MefService.run_efiler_command(mef_credentials, "submit", submission_path)
    end
  end

  def self.transmitted?(mef_response, submission_bundle_filename)
    submission_id = File.basename(submission_bundle_filename, ".zip")
    doc = Nokogiri::XML(mef_response)
    doc.css("SubmissionReceiptList SubmissionReceiptGrp SubmissionId").text.strip == submission_id
  end
end
