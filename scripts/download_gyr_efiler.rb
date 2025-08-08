require "zip"
require "aws-sdk-s3"
require "dotenv/load"

CURRENT_VERSION = "d8645b36cf2a9faa0593edb703411d8f4bea10df"
download_paths = [
  "gyr_efiler/gyr-efiler-classes-#{CURRENT_VERSION}.zip",
  "gyr_efiler/gyr-efiler-config-#{CURRENT_VERSION}.zip"
]

# If the file already exists, do not re-download.
exit if download_paths.all? { |p| File.exist?(p) }

download_paths.each do |path|
  Aws::S3::Client.new.get_object(
    response_target: path,
    bucket: "gyr-efiler-release",
    key: File.basename(path)
  )
end
