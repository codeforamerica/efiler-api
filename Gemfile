source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }
ruby_version = File.read(File.join(File.dirname(__FILE__), '.ruby-version')).strip
ruby ruby_version

gem 'sinatra', :github => 'sinatra/sinatra'
gem "rackup", "~> 2.2"
gem "puma", "~> 6.6"
gem 'aws-sdk-s3'
gem 'rubyzip'

group :development, :test do
  gem 'pry-byebug'
end
