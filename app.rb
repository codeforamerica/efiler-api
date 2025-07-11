require 'sinatra'
require 'pry-byebug'
require 'jwt'
require_relative "efiler_service"
require_relative "extensions/jwt_auth"

before do
  content_type 'application/json'
end

authenticate_jwt

get '/' do
  'Hello world!'
end

# TODO: this endpoint should take a submission ID
get '/efile' do
  puts "doing efile"
  EfilerService.run_efiler_command("test", "submissions-status", "4414662025127ohzns0q") # a test submission id from demo
  { foo: :bar }.to_json
rescue StandardError => e
  status 500
  { exception: e.detailed_message }.to_json
end

post '/submit/:id' do
  EfilerService.run_efiler_command("test", "submit", params[:id])
  # TODO: maybe add a check if the response was successful
  status 201
  { foo: :bar }.to_json
rescue StandardError => e
  status 500
  { exception: e.message }.to_json
end

get '/submissions-status/:id' do
  EfilerService.run_efiler_command("test", "submissions-status", params[:id])
  status 200
  { foo: :bar }.to_json
rescue StandardError => e
  status 500
  { exception: e.message }.to_json
end

get '/acks/:id' do
  EfilerService.run_efiler_command("test", "acks", params[:id])
  status 200
  { foo: :bar }.to_json
rescue StandardError => e
  status 500
  { exception: e.message }.to_json
end
