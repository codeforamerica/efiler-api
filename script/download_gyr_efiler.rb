require_relative "../config/environment"

CURRENT_VERSION = "8c46c9dccfc4da4b0acec5813966b1ba68abe245"
download_paths = [
  "gyr_efiler/gyr-efiler-classes-#{CURRENT_VERSION}.zip",
  "gyr_efiler/gyr-efiler-config-#{CURRENT_VERSION}.zip"
]

# If the file already exists, do not re-download.
exit if download_paths.all? { |p| File.exist?(p) }

credentials = Aws::Credentials.new(ENV["GYR_EFILER_RELEASES_AWS_ACCESS_KEY_ID"], ENV["GYR_EFILER_RELEASES_AWS_SECRET_ACCESS_KEY"])
download_paths.each do |path|
  download_dir = File.dirname(path)
  FileUtils.mkdir_p(download_dir) unless Dir.exist?(download_dir)

  Aws::S3::Client.new(region: "us-east-1", credentials: credentials).get_object(
    response_target: path,
    bucket: "gyr-efiler-releases",
    key: File.basename(path)
  )
end
