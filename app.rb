require 'sinatra'
require 'pry-byebug'
require "./efiler_service.rb"

get '/' do
  'Hello world!'
end

get '/efile' do
  puts "doing efile"
  EfilerService.run_efiler_command("test", "acks", "43164321897643267891")
end