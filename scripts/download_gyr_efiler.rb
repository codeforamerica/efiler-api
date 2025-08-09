if %w[development test].include? ENV["RACK_ENV"]
  require "dotenv"
  Dotenv.load(overwrite: true)
end

require "zip"
require "aws-sdk-s3"

CURRENT_VERSION = "d8645b36cf2a9faa0593edb703411d8f4bea10df"
download_paths = [
  "gyr_efiler/gyr-efiler-classes-#{CURRENT_VERSION}.zip",
  "gyr_efiler/gyr-efiler-config-#{CURRENT_VERSION}.zip"
]

# If the file already exists, do not re-download.
exit if download_paths.all? { |p| File.exist?(p) }

credentials = Aws::Credentials.new(ENV["GYR_EFILER_RELEASES_AWS_ACCESS_KEY_ID"], ENV["GYR_EFILER_RELEASES_AWS_SECRET_ACCESS_KEY"])
download_paths.each do |path|
  Aws::S3::Client.new(region: "us-east-1", credentials: credentials).get_object(
    response_target: path,
    bucket: "gyr-efiler-releases",
    key: File.basename(path)
  )
end
