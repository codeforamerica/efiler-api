module Api::V0
  class EfileController < BaseController
    def submit
      submission_bundle = params.expect(:submission_bundle)
      base64_encoded_submission_bundle = Base64.strict_encode64(submission_bundle.read)
      webhook_url = CGI.unescape(params.expect(:webhook_url))
      Mef::SubmitJob.perform_later(
        api_request_id,
        webhook_url,
        api_client_name,
        submission_bundle.original_filename,
        base64_encoded_submission_bundle
      )
      render json: {api_request_id:}
    end

    def submissions_status
      submission_ids = params.expect(id: [])
      webhook_url = CGI.unescape(params.expect(:webhook_url))
      Mef::SubmissionsStatusJob.perform_later(api_request_id, webhook_url, api_client_name, submission_ids)
      render json: {api_request_id:}
    end

    def acks
      submission_ids = params.expect(id: [])
      webhook_url = CGI.unescape(params.expect(:webhook_url))
      Mef::AcksJob.perform_later(api_request_id, webhook_url, api_client_name, submission_ids)
      render json: {api_request_id:}
    end
  end
end
