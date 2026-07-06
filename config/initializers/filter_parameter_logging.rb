# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
#
# This API receives tax-return submission bundles. The bundle itself is the most sensitive payload
# (XML containing SSNs, names, addresses, income, bank routing/account numbers), so it is filtered
# from request parameter logging. These filters do NOT scrub values interpolated directly into log
# messages — keep PII out of those by hand (see MefJob / BaseController).
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,

  # The tax-return submission bundle (base64 ZIP of return XML): sensitive PII, an opaque multi-MB
  # blob as-logged, and available for debugging through the stored artifact rather than the request log
  :submission_bundle,

  # Client callback URL (may carry credentials/tokens in the path or query)
  :webhook_url
]
