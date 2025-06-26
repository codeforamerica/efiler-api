require 'zip'
require "aws-sdk-s3"

CURRENT_VERSION = 'ae332c44bac585fb9dbec9bf32ffff0d34a72830'
download_paths = [
  "gyr_efiler/gyr-efiler-classes-#{CURRENT_VERSION}.zip",
  "gyr_efiler/gyr-efiler-config-#{CURRENT_VERSION}.zip"
]

# If the file already exists, do not re-download.
exit if download_paths.all? { |p| File.exist?(p) }

# On Circle CI, get AWS credentials from environment.
# In staging, demo, and prod environment, get credentials from Rails credentials.
#
# In development, download the file manually from S3. This allows us to avoid storing any AWS credentials in the development secrets.
access_key_id = "fake-access-key-id"
secret_access_key = "fake-access-key"
credentials =  Aws::Credentials.new(access_key_id, secret_access_key)

download_paths.each do |path|
  Aws::S3::Client.new(region: 'us-east-1', credentials: credentials).get_object(
    response_target: path,
    bucket: "gyr-efiler-releases",
    key: File.basename(path),
  )
end