module Api::V0
  class EfileController < BaseController
    def submit
      submission_bundle = params.expect(:submission_bundle)

      submission_filename = submission_bundle.original_filename
      result = Dir.mktmpdir do |dir|
        submission_path = File.join(dir, submission_filename)
        FileUtils.mv submission_bundle.tempfile.path, submission_path
        MefService.run_efiler_command(get_api_client_mef_credentials, "submit", submission_path)
      end

      doc = Nokogiri::XML(result)
      if doc.css("SubmissionReceiptList SubmissionReceiptGrp SubmissionId").text.strip == File.basename(submission_filename, ".zip")
        render json: {status: "transmitted", result: result}, status: :created
      else
        render json: {status: "failed", result: result}, status: :bad_request
      end
    end

    def submissions_status
      submission_ids = params.expect(id: [])
      response = MefService.run_efiler_command(get_api_client_mef_credentials, "submissions-status", *submission_ids)
      render json: Mef::SubmissionsStatus.handle_submission_status_response(response)
    end

    def acks
      submission_ids = params.expect(id: [])
      response = MefService.run_efiler_command(get_api_client_mef_credentials, "acks", *submission_ids)
      render json: Mef::Acks.handle_ack_response(response)
    end
  end
end
