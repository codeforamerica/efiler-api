require_relative "../config/environment"

LIVE_VERSIONS = [MefService::V16, MefService::V17].freeze

credentials = Aws::Credentials.new(ENV["GYR_EFILER_RELEASES_AWS_ACCESS_KEY_ID"], ENV["GYR_EFILER_RELEASES_AWS_SECRET_ACCESS_KEY"])
LIVE_VERSIONS.each do |version|
  download_paths = [
    "gyr_efiler/gyr-efiler-classes-#{version}.zip",
    "gyr_efiler/gyr-efiler-config-#{version}.zip"
  ]
  download_paths.each do |path|
    next if File.exist?(path)
    download_dir = File.dirname(path)
    FileUtils.mkdir_p(download_dir) unless Dir.exist?(download_dir)

    Aws::S3::Client.new(region: "us-east-1", credentials: credentials).get_object(
      response_target: path,
      bucket: "gyr-efiler-releases",
      key: File.basename(path)
    )
  end
end
