module Mef
  class MefJob < ApplicationJob
    attr_accessor :webhook_url, :api_request_id, :mef_credentials

    queue_as :mef
    retry_on MefService::RetryableError

    after_discard do |job, exception|
      log_and_respond_with_error(job, exception)
    end

    def log_and_respond_with_error(job, exception)
      # exception can wrap the MeF SDK audit log / Java output (taxpayer data), so production logs the
      # class and correlates by request id; non-production logs it in full for debugging. Either way
      # the full detail is still relayed to the client via the webhook below.
      loggable_exception = Rails.env.production? ? exception.class : exception
      Rails.logger.error("#{job.class.name} (api_request_id=#{job.api_request_id}) has been discarded due to #{loggable_exception}")
      WebhookCallbackJob.perform_later(
        api_request_id,
        webhook_url,
        {error: exception.detailed_message}
      )
    end

    def perform(api_request_id, webhook_url, api_client_name, *args)
      self.api_request_id = api_request_id
      self.webhook_url = webhook_url
      self.mef_credentials = MefService.get_mef_credentials(api_client_name)

      perform_mef_request(*args)
    end
  end
end
