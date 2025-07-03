require 'sinatra'
require 'pry-byebug'
require "./efiler_service.rb"

get '/' do
  'Hello world!'
end

# TODO: this endpoint should take a submission ID
get '/efile' do
  puts "doing efile"
  EfilerService.run_efiler_command("test", "submissions-status", "4414662025127ohzns0q") # a test submission id from demo
end

post '/submit/:id' do
  EfilerService.run_efiler_command("test", "submit", params[:id])
  # TODO: maybe add a check if the response was successful
  status 201
end

get '/submissions-status/:id' do
  EfilerService.run_efiler_command("test", "submissions-status", params[:id])
  status 200
end

get '/acks/:id' do
  EfilerService.run_efiler_command("test", "acks", params[:id])
  status 200
end
