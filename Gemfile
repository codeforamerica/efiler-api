source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }
ruby_version = File.read(File.join(File.dirname(__FILE__), ".ruby-version")).strip
ruby ruby_version

gem "sinatra", github: "sinatra/sinatra"
gem "rackup", "~> 2.2"
gem "puma", "~> 6.6"
gem "aws-sdk-s3"
gem "aws-sdk-secretsmanager"
gem "rubyzip"
gem "jwt"
gem "nokogiri"

# TODO: Move this back into group :development when we figure out how to set the RACK_ENV environment variable on demo
gem "dotenv"

group :development do
  gem "standard"
  gem "rerun"
end

group :development, :test do
  gem "byebug", platforms: [:mri, :mingw, :x64_mingw]
  gem "pry-byebug"
  gem "rack-test"
  gem "rspec"
end
