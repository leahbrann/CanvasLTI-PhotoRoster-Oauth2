require 'oauth2'
require 'sinatra'
require 'openssl'
require 'json'
require 'httparty'
require 'sass'
require 'rack-lti'
require 'dotenv'

Dotenv.load
enable :sessions


client = OAuth2::Client.new("#{ENV['CANVAS_ID']}", "#{ENV['CANVAS_KEY']}", :site => "#{ENV['CANVAS_URL']}", :authorize_url => "#{ENV['CANVAS_URL']}/l
gin/oauth2/auth",
      :token_url => "#{ENV['CANVAS_URL']}/login/oauth2/token")


# User tokens are stored so that a user only needs to authorize once (except not yet)
    @@token_cache = {}


get '/' do
  erb :layout do
      erb :mindex
   end
end

get '/auth' do
redirect client.auth_code.authorize_url(:redirect_uri => "#{ENV['REDIRECT_URI']}")
end

get '/oauth2callback' do
  access_token = client.auth_code.get_token(params[:code], :redirect_uri => "#{ENV['REDIRECT_URI']}")
  session[:access_token] = access_token.token
  @message = "Successfully authenticated with the server"

  # TODO: implement token caching
  @@token_cache[session[:user]] = access_token.token

 redirect to '/success'
end

get '/success' do

  @access_token = session[:access_token]
  courses_api     = ("#{ENV['CANVAS_URL']}/api/v1/courses?access_token=#{current_token}")

  canvas_response = HTTParty.get(courses_api)
  courses = canvas_response.parsed_response
  @coursestaught = courses.select{|course| course["enrollments"].flat_map{|x| x["type"]}.include? "teacher"}

    erb :success
end

get '/courses/:course_id' do
   @course = "#{params[:course_id]}"
   course_enrollment_api = ("#{ENV['CANVAS_URL']}/api/v1/courses/#{@course}/users?access_token=#{current_token}&enrollment_type=student")
   @course_enrollments = HTTParty.get(course_enrollment_api)

   erb :layout do
      erb :course
   end
end

get '/stylesheet.css' do
  scss :'sass/stylesheet'
end


 private

  # Helper method to retrieve the current user's API token.
  def current_token
    @@token_cache[session[:user]]
  end