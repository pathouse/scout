#!/usr/bin/env ruby

require './config/environment'
require 'sinatra/content_for'
require 'sinatra/flash'
require 'rack/file'

set :logging, false
set :views, 'app/views'
set :public_folder, 'public'

# disable sessions in test environment so it can be manually set
unless test?
  use Rack::Session::Cookie, 
    key: 'rack.session',
    path: '/',
    expire_after: (60 * 60 * 24 * 30), # 30 days
    secret: Environment.config['session_secret']
end


# TODO: seriously?
disable :protection

configure(:development) do |config|
  require 'sinatra/reloader'
  config.also_reload "./config/environment.rb"
  config.also_reload "./config/admin.rb"
  config.also_reload "./config/email.rb"
  config.also_reload "./config/sms.rb"
  config.also_reload "./app/helpers/*.rb"
  config.also_reload "./app/models/*.rb"
  config.also_reload "./app/controllers/*.rb"
  config.also_reload "./subscriptions/adapters/*.rb"
  config.also_reload "./subscriptions/*.rb"
  config.also_reload "./deliveries/*.rb"
end

Dir.glob("./app/controllers/*.rb").each {|filename| load filename}


before do
  # interest count is displayed in layout header for logged in users
  @interest_count = logged_in? ? current_user.interests.count : 0

  # lightweight server-side campaign conversion tracking 
  # [:utm_source, :utm_medium, :utm_content, :utm_campaign].each do |campaign|
  #   if params[campaign].present?
  #     session['campaign'] ||= {}
  #     session['campaign'][campaign] = params[campaign]
  #   end
  # end

  @start_time = Time.now
end

after do
  # for now, log google hits in a database, to understand behavior better
  Event.google!(env, @start_time) if google?
end


get '/' do
  erb :index
end

get '/about' do
  erb :about
end

get '/error' do
  raise Exception.new("KABOOM.")
end

post '/error' do
  raise Exception.new("KABOOM.")
end

# redirector and tracker
# * records the click event and data, redirects user to final URL
# 
# recognized params:
#   * from - 'email'
#   * to - url to redirect to (generated at email render time)
# 
# And a 'd' hash that can contain:
#   * remote - a remote service name, e.g. "open_states"
#   * url_type - 'item' 
# 
# and if this is to a landing:
#   * item_type - type of landing page
#   * item_id - ID of landing item
#   * because - 'search' if a search result, 'item' if an item subscription
#   * query - for 'search' - search term

get '/url' do 
  halt 500 unless params[:to].present?
  
  if params[:from] == "email"
    Event.email_click! (params[:d] || {}).merge(to: params[:to])
  end

  redirect params[:to]
end


# custom 404 and 500 handlers

not_found do
  erb :"404"
end

error do
  exception = env['sinatra.error']
  name = exception.class.name
  message = exception.message

  request = {
    method: env['REQUEST_METHOD'], 
    url: [Environment.config['hostname'], env['REQUEST_URI']].join,
    params: params.inspect,
    user_agent: env['HTTP_USER_AGENT']
  }
  
  if current_user
    request[:user] = current_user.id.to_s
  end

  Admin.report Report.exception("Exception Notifier", "#{name}: #{message}", exception, request: request)
  erb :"500"
end


helpers do

  def pjax?
    (request.env['HTTP_X_PJAX'] or params[:_pjax]) ? true : false
  end

  def logged_in?
    !current_user.nil?
  end

  def crawler?
    ["googlebot", "twitterbot", "facebookexternalhit", "msnbot"].each do |agent|
      if request.env['HTTP_USER_AGENT'] =~ /#{agent}/i
        return true
      end
    end

    false
  end

  def google?
    !!(request.env['HTTP_USER_AGENT'] =~ /googlebot/i)
  end
  
  def current_user
    @current_user ||= (session['user_id'] ? User.find(session['user_id']) : nil)
  end

  def requires_login(path = '/')
    redirect path unless logged_in?
  end

  # done as the end of an endpoint
  def json(code, object)
    headers["Content-Type"] = "application/json"
    status code
    object.to_json
  end

  def load_user
    user_id = params[:user_id].strip
    if user = User.where(username: user_id).first
      user
    else # can be nil
      User.find user_id
    end
  end

end