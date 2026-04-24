class WebhookCallbackJob < ApplicationJob
  queue_as :webhook_callback

  def perform(api_request_id, webhook_url, payload)
    payload_with_api_request_id = payload.merge({api_request_id:})
    webhook_uri = URI.parse(webhook_url)
    conn = Faraday.new(url: webhook_uri.origin, headers: {"Content-Type" => "application/json"})
    conn.post(webhook_uri.path) do |req|
      req.options.timeout = 5
      req.body = payload_with_api_request_id.to_json
    end
  end
end
