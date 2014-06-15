require 'oauth2'
require 'sinatra'
require 'httparty'
require 'sass'
require 'dotenv'
require 'data_mapper'
require 'rack-lti'
require 'pry'

Dotenv.load
enable :sessions
set :protection, :except => :frame_options


# #DB config for storing user tokens
DataMapper.setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/mydb')
DataMapper::Property::String.length(255)

class User
  include DataMapper::Resource
  property :id, Serial, :key => false
  property :user_id, String, :key => true 
  property :access_token, String
end

class Nonce
  include DataMapper::Resource
  property :id, Serial, :key => false
  property :oauth_nonce, String, :key => true
  property :timestamp, DateTime 
end 

DataMapper.finalize
DataMapper.auto_upgrade!

 use Rack::LTI,
    # Pass the consumer key and secret
    consumer_key: "#{ENV['CONSUMER_KEY']}",
    consumer_secret: "#{ENV['CONSUMER_SECRET']}",

    # This is the URL to redirect to on a valid launch.
    app_path: '/oauth/launch',

    # This is the URL that hosts the tool's XML configuration.
    config_path: '/lti/config.xml',

    # This is the URL clients (e.g. Canvas) will POST launch requests to.
    launch_path: '/lti/launch',

    nonce_validator: ->(nonce) {
      Nonce.get(nonce).nil? && Nonce.create(:oauth_nonce => nonce, :timestamp => DateTime.now)
    },

    # Fail request older than 1 hour.
    time_limit: 3_600, # one hour

    # On a successful launch, take the user's ID from the launch and store
    # it in the session before redirecting.
    success: ->(params, request, response) {
      request.env['rack.session'][:user] = params['user_id']
          },

    # Use Instructure's course_navigation extension to display a link to
    # the tool in Canvas' course navigation.
    extensions: {
      'canvas.instructure.com' => {
        user_navigation: {
          enabled: 'true',
          text: 'Photo Roster'
        }
      }
    },

    # The title and description of the tool. Visible in the configuration.
    title: 'Course Photo Roster',
    description: <<-END
Student photos for courses in which the user is a teacher.
    END


client = OAuth2::Client.new("#{ENV['CANVAS_ID']}", "#{ENV['CANVAS_KEY']}", :site => "#{ENV['CANVAS_URL']}", :authorize_url => "#{ENV['CANVAS_URL']}/login/oauth2/auth",
      :token_url => "#{ENV['CANVAS_URL']}/login/oauth2/token")

get '/oauth/launch' do
    if stored_user
      redirect '/courses'
    else
      redirect client.auth_code.authorize_url(:redirect_uri => "#{ENV['REDIRECT_URI']}")
    end
end

get '/oauth2callback' do
  access_token = client.auth_code.get_token(params[:code], :redirect_uri => "#{ENV['REDIRECT_URI']}")
  session[:access_token] = access_token.token
  
  User.create(:user_id => session[:user], :access_token => access_token.token)

   redirect to '/courses'
end

get '/courses' do

  courses_api     = ("#{ENV['CANVAS_URL']}/api/v1/courses?access_token=#{current_token}")

  canvas_response = HTTParty.get(courses_api)
  courses = canvas_response.parsed_response
  @coursestaught = courses.select{|course| course["enrollments"].flat_map{|x| x["type"]}.include? "teacher"}

  erb :layout do
    erb :success
  end  
end

get '/courses/:course_id' do
   @course = "#{params[:course_id]}"
   course_enrollment_api = ("#{ENV['CANVAS_URL']}/api/v1/courses/#{@course}/users?access_token=#{current_token}&enrollment_type=student")
   @course_enrollments = HTTParty.get(course_enrollment_api)
   @photos_path = "#{ENV['PHOTOS_PATH']}"

   erb :layout do
      erb :course
   end
end

get '/stylesheet.css' do
  scss :'sass/stylesheet'
end


 private

  # Helper method to retrieve the current user's API token.
  def stored_user
    !User.get(session[:user]).nil?
  end

  def current_token
    current_user = User.get(session[:user])
    current_user.access_token    
  end