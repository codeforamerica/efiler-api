module Mef
  class AcksJob < MefJob
    def perform_mef_request(submission_ids)
      mef_response = MefService.run_efiler_command(mef_credentials, "acks", *submission_ids)
      parsed_response = Mef::Acks.parse_acks_response(mef_response)
      WebhookCallbackJob.perform_later(api_request_id, webhook_url, {result: parsed_response})
    end
  end
end
