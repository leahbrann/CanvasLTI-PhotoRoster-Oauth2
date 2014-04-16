require 'oauth2'
require 'sinatra'
require 'openssl'
require 'json'
require 'httparty'

enable :sessions

CANVAS_URL      = 'https://usfca.instructure.com'


#redirect_uri = 'http://ltidev-c9-leahbrann.c9.io'
redirect_uri = 'http://localhost:4567/oauth2callback'
client = OAuth2::Client.new('***REMOVED***', '***REMOVED***', :site => CANVAS_URL, :authorize_url => "#{CANVAS_URL}/login/oauth2/auth",
      :token_url => "#{CANVAS_URL}/login/oauth2/token")

 # User tokens are stored so that a user only needs to authorized this
  # application once.
  @@token_cache = {}

get '/' do
    erb :mindex
end    

get '/auth' do      
redirect client.auth_code.authorize_url(:redirect_uri => redirect_uri)
end

# get '/oauth2callback' do
#     # We make one more request to Canvas to exchange our temporary token for a
#     # permanent user token.
#     canvas_url = URI("#{site_path}/login/oauth2/token")
#     response = Net::HTTP.post_form(canvas_url, client_id: '***REMOVED***', redirect_uri: redirect_uri, client_secret: '***REMOVED***', code: params[:code])
#     # Once we have the token, we store it in @@token_cache so it can be reused.
#     @@token_cache[session[:user]] = JSON.parse(response.body)['access_token']

#     # Redirect to the index to launch the application.
#     redirect '/success'
#   end


get '/oauth2callback' do
  access_token = client.auth_code.get_token(params[:code], :redirect_uri => redirect_uri)
  session[:access_token] = access_token.token
  @message = "Successfully authenticated with the server"
  # Once we have the token, we store it in @@token_cache so it can be reused.
  @@token_cache[session[:user]] = access_token.token
 
  #@access_token = session[:access_token]
 
  # parsed is a handy method on an OAuth2::Response object that will 
  # intelligently try and parse the response.body
  #@email = access_token.get('https://www.googleapis.com/userinfo/email?alt=json').parsed
  redirect to '/success'
end

get '/success' do

  @access_token = session[:access_token]
  courses_api     = ("#{CANVAS_URL}/api/v1/courses?access_token=#{current_token}")
 
  canvas_response = HTTParty.get(courses_api)
  courses = canvas_response.parsed_response
  @coursestaught = courses.select{|course| course["enrollments"].flat_map{|x| x["type"]}.include? "teacher"}

    erb :success
end    


 private

  # Helper method to retrieve the current user's API token.
  def current_token
    @@token_cache[session[:user]]
  end