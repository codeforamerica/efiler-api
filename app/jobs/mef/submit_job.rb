module Mef
  class SubmitJob < ApplicationJob
    def perform(api_request_id, webhook_url, api_client_name, submission_bundle_filename, submission_bundle_contents_base64)
      mef_credentials = MefService.get_mef_credentials(api_client_name)

      mef_response = Dir.mktmpdir do |dir|
        submission_path = File.join(dir, submission_bundle_filename)
        File.binwrite(submission_path, Base64.strict_decode64(submission_bundle_contents_base64))
        MefService.run_efiler_command(mef_credentials, "submit", submission_path)
      end

      submission_id = File.basename(submission_bundle_filename, ".zip")
      doc = Nokogiri::XML(mef_response)
      if doc.css("SubmissionReceiptList SubmissionReceiptGrp SubmissionId").text.strip == submission_id
        WebhookCallbackJob.perform_later(api_request_id, webhook_url, {status: "transmitted", result: mef_response})
      else
        WebhookCallbackJob.perform_later(api_request_id, webhook_url, {status: "failed", result: mef_response})
      end
    end
  end
end
