module Mef
  module Client
    # A MeF WSDL release. Behavior shared across releases lives in the client; a release
    # subclass (see Releases) declares its version and when MeF switches to it, and overrides
    # only what that release changes.
    class Release
      WSDL_DIR = Rails.root.join("mef_wsdls")

      def self.wsdl_version
        raise NotImplementedError
      end

      # The first day MeF serves this release in each environment ("test" is ATS). A release
      # without a date for an environment is in effect there until a later release's date.
      def self.cutover_dates
        {}
      end

      def self.for(mef_env, on: Date.current)
        Releases::ALL.rfind { |release| release.in_effect?(mef_env, on) }
      end

      def self.in_effect?(mef_env, date)
        cutover = cutover_dates[mef_env]
        cutover.nil? || cutover <= date
      end

      # The IRS's WSDL/XSD files for this release, which may not be redistributed; see
      # script/download_mef_wsdls.rb.
      def self.wsdl_dir
        WSDL_DIR.join(wsdl_version)
      end
    end
  end
end
