class WebhookCallbackJob < ApplicationJob
  queue_as :webhook_callback

  def perform(api_request_id, webhook_url, payload)
    payload_with_api_request_id = payload.merge({api_request_id:})
    uri = URI.parse(webhook_url)
    conn = Faraday.new(url: "#{uri.scheme}://#{uri.host}", headers: {"Content-Type" => "application/json"})
    conn.post(uri.path) do |req|
      req.body = payload_with_api_request_id.to_json
    end
  end
end
