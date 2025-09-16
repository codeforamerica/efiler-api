module Mef
  class SubmitJob < MefJob
    def perform_mef_request(submission_bundle_filename, submission_bundle_contents_base64)
      mef_response = Mef::Submit.send_submission_bundle(
        mef_credentials,
        submission_bundle_filename,
        submission_bundle_contents_base64
      )

      if Mef::Submit.transmitted?(mef_response, submission_bundle_filename)
        WebhookCallbackJob.perform_later(api_request_id, webhook_url, {status: "transmitted", result: mef_response})
      else
        WebhookCallbackJob.perform_later(api_request_id, webhook_url, {status: "failed", result: mef_response})
      end
    end
  end
end
