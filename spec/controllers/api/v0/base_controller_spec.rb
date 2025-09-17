require "rails_helper"

class FakeController < Api::V0::BaseController; end

describe FakeController, type: :controller do
  context "verifying the client" do
    let(:client_app_name) { "ClientAppName" }
    let(:jwt) { JWT.encode({iss: client_app_name, efiler_api_public_key: OpenSSL::PKey::RSA.new(PUBLIC_KEY)}, OpenSSL::PKey::RSA.new(PRIVATE_KEY), "RS256") }
    before do
      request.headers["Authorization"] = "Bearer #{jwt}"
    end

    describe "#verify_client_name_and_signature" do
      it "verifies the request has a valid JWT with cert and client app name" do
        allow(MefService).to receive(:get_mef_credentials).with(client_app_name).and_return({efiler_api_public_key: Base64.encode64(PUBLIC_KEY), app_sys_id: "foo", etin: "bar"})

        expect {
          subject.verify_client_name_and_signature
        }.not_to raise_error
      end

      it "raises JWT::VerificationError when cert is not valid" do
        allow(MefService).to receive(:get_mef_credentials).with(client_app_name).and_return({efiler_api_public_key: Base64.encode64(WRONG_PUBLIC_KEY), app_sys_id: "foo", etin: "bar"})

        expect {
          subject.verify_client_name_and_signature
        }.to raise_error(JWT::VerificationError)
      end
    end
  end

  context "error handling" do
    before do
      allow_any_instance_of(described_class).to receive(:verify_client_name_and_signature).and_return(true)
    end

    context "when it encounters a missing parameters error" do
      controller do
        def index
          params.fetch(:boop)
          head :ok
        end
      end

      it "returns a bad request response" do
        get :index

        expect(response.body).to eq("param is missing or the value is empty or invalid: boop")
        expect(response).to be_bad_request
      end
    end

    context "when it encounters a jwt verification error" do
      controller do
        def index
          raise JWT::VerificationError
        end
      end

      it "returns unauthorized" do
        get :index

        expect(response).to be_unauthorized
      end
    end
  end
end

PUBLIC_KEY = <<~PUB
  -----BEGIN PUBLIC KEY-----
  MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAi11NTb3EiWRNqz1TdbuM
  9WhQpPy+boFMuhyM8zMRAoDUlza3hXuUSaWYBmm5nJpnRzLCCQHQSciw1UTx76y/
  AEcpzqTygoa0v4vogHVMs8Y7IjggZ6CbMqyRaT40/wRkj/NFXi7RSjTU03ChTkG/
  XKZbIYqDZCJ5Sk0sM4smQBEzvx78agDumyCjXEUgdIVhwKHQiyw4BC2IZoBNmVia
  M+sJG0oX3ClW25iBnzTqpqUcNdrw8bMnk2kJvTE0NspVyE9cEYb3wgm6yl+WfyIG
  nI8QAyxSvOfhQxhLgFeRXECyOEhwtQ2X+dO8fWO8tvoW9je4W0Xs0yAGSaock8MY
  tQIDAQAB
  -----END PUBLIC KEY-----
PUB
PRIVATE_KEY = <<~PRIV
  -----BEGIN PRIVATE KEY-----
  MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCLXU1NvcSJZE2r
  PVN1u4z1aFCk/L5ugUy6HIzzMxECgNSXNreFe5RJpZgGabmcmmdHMsIJAdBJyLDV
  RPHvrL8ARynOpPKChrS/i+iAdUyzxjsiOCBnoJsyrJFpPjT/BGSP80VeLtFKNNTT
  cKFOQb9cplshioNkInlKTSwziyZAETO/HvxqAO6bIKNcRSB0hWHAodCLLDgELYhm
  gE2ZWJoz6wkbShfcKVbbmIGfNOqmpRw12vDxsyeTaQm9MTQ2ylXIT1wRhvfCCbrK
  X5Z/IgacjxADLFK85+FDGEuAV5FcQLI4SHC1DZf507x9Y7y2+hb2N7hbRezTIAZJ
  qhyTwxi1AgMBAAECggEAAvRr9ql+2MDhKq/GrLjYwL1A9HaNXQ9tvoZrcJ6VDj4I
  A9q7ol9f4f3aTsyADHNznB1V4tYAggf4w9TN4lyBwjJADysNHzpW67a+K7cQ9MDP
  sSaKfVf44mapQJd6jSudLDYmstwAQPgEySTarquTMJYwWXIz3fQjKTGgrckV+wa6
  VOcIQ9xQuF6chNeIUsrb0/J6+7+Om/44enA2HPi6r+rcqTXeaXvG7pB4XahYcWF5
  r+bEM7MFjjSPKc0HIyLkSz1OFS0dooXDJssPbKc5bXUm2E0cR8XPNMcmMiZ5qUJJ
  XRRM7hSICvXen86CAH6cYUlEcz3yOCF80PVxUEpTYwKBgQDAL9GD3zpURcsHy2bc
  wYJ3+853g9fdtJ9xcbWy0ksfgBXhKkepqnBKBNb8l/Z318IbH641V4z70LTtxtvO
  u+wmeHfK00qeB5BqXgGEgwvU1n1aVaqMZfCWfZZHNtx9mPTQTjd7IG9cH0Qfz5Jy
  j76kTYNTB09vQagwMiwXGdaXkwKBgQC5o4B5ZBIgPbDTlUfNitBRQTjgT1wGYXUh
  bbWXhQgzAaofLUAJKphFbfEohE2hMdaOPIFHibXsKAOKWN2+nxDFcUNhQJgi5FCo
  S4iudNPyFewRtrojCI5Hn5TQXlxAfWMqh3fa40uUeWQdtLPBK9FB2speatPcWFDh
  J+8YCp4rlwKBgAg+RNNOMNdKgxHbhJb1ad4xm8J+kjS9OZWJFg0MfhJk0QtuX9KE
  L/rMyFffQMAVLgsxyawaDD8Eza3hOK5eWxuvURwPAgVTN7uIOrJvWIORi6DjScRp
  3u7lhhuZ2807UUzZ/gE2++/Mm4Rtx89IIRo1BOv7xUl1XHxsun1nK1AnAoGAAu/4
  X3Na6hGv05lAGpuAslhy2vHGhf9SyCWhQvWC7LOxCm8/3SVEZYzYzQhS5iMQvw1s
  CkK+ky8K50yCrbp8nHMvWsGX5q1wLUmMrx4AIIuCQcF/boB7J9z5kNZ9ZTPWttyP
  4/HGx2GoWOP8GClmVUFuBFJyacEn/ngQS3QXjp8CgYEAohXw6s0/Ma9HKEn41giK
  edgwtSO3c3P/AJVoQ3LG3L6xOWR2XtUnulHnpCSlcfVSRTzLqAcRrjTaGCqtXVjL
  I0hqaX6g3S0PkkviJSDEBkqEbtgpfM9YWmldhyWnChnNec7a9Ivlrdu/u7M1bGfv
  rcI5nHUkyoAFoAI0V/Kg2IA=
  -----END PRIVATE KEY-----
PRIV
WRONG_PUBLIC_KEY = <<~PUB
  -----BEGIN PUBLIC KEY-----
  MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArhYW/0hyg3/Qs//aT7nu
  omjYv9BcU74Pi76Fcw6BqepKwjLZufjKsoPcWjQBCF1bYTTRGcAGbFJlT4ld/pHd
  4L25znBbZNoRA24O+3G1ZzYk3HWF3sCgwRTu+/57zCUBvH/uQ3A2Agmh+TGHq3Ky
  oTrcKeQVedPTA6uWFtwrjYl+OXAK7w46UfFNb4HdsCQ67JZ7rdNZW6gDIXY1MU93
  Z/wBUC4fnJ/7VOvkLjzPctq93LvvO3KlVXFImZz7X2X67/Vr5t+zOIDRch4kmtQs
  H7m1Un+2j56BmF8eYIH1bJdFszObuG+RE5hCJcUOk+B5fw98j/yvBDwVTt726Rrz
  JQIDAQAB
  -----END PUBLIC KEY-----
PUB
