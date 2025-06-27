require 'sinatra'
require 'pry-byebug'
require "./efiler_service.rb"

get '/' do
  'Hello world!'
end

get '/efile' do
  puts "doing efile"
  EfilerService.run_efiler_command("test", "submissions-status", "4414662025127ohzns0q") # a test submission id from demo
end