require_relative "../config/environment"

# The IRS distributes each MeF release's WSDLs and XSDs only to registered transmitters, so they
# may not be committed here; each is stored privately as <MEF_WSDLS_S3_BUCKET>/<version>.zip.
s3 = Aws::S3::Client.new(region: "us-east-1")

Mef::Client::Releases::ALL.each do |release|
  next if release.wsdl_dir.exist?

  zip = s3.get_object(bucket: ENV.fetch("MEF_WSDLS_S3_BUCKET"), key: "#{release.wsdl_version}.zip").body
  FileUtils.mkdir_p(release.wsdl_dir)
  Zip::File.open_buffer(zip) do |zipfile|
    zipfile.each do |entry|
      next unless entry.file? && entry.name.end_with?(".wsdl", ".xsd")

      File.binwrite(release.wsdl_dir.join(File.basename(entry.name)), entry.get_input_stream.read)
    end
  end
end
