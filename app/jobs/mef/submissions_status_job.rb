module Mef
  class SubmissionsStatusJob < ApplicationJob
    def perform(api_request_id, webhook_url, api_client_name, submission_ids)
      mef_credentials = MefService.get_mef_credentials(api_client_name)
      mef_response = MefService.run_efiler_command(mef_credentials, "submissions-status", *submission_ids)
      WebhookCallbackJob.perform_later(
        api_request_id,
        webhook_url,
        {result: Mef::SubmissionsStatus.parse_submissions_status_response(mef_response)}
      )
    end
  end
end
