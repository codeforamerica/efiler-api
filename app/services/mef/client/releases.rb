module Mef
  module Client
    # The IRS publishes one WSDL release per processing year.
    module Releases
      class ProcessingYear2026 < Release
        def self.wsdl_version = "10.9"
      end

      # https://www.irs.gov/e-file-providers/modernized-e-file-mef-status (September 3, 2026):
      # installed in ATS on October 13, 2026 and required in production for processing year 2027.
      class ProcessingYear2027 < Release
        def self.wsdl_version = "10.A"

        def self.cutover_dates = {"test" => Date.new(2026, 10, 13), "prod" => Date.new(2027, 1, 1)}
      end

      # Oldest first.
      ALL = [ProcessingYear2026, ProcessingYear2027]
    end
  end
end
