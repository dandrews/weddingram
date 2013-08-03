class ApplicationController < ActionController::Base
  http_basic_authenticate_with :name => ENV["BASICAUTH_NAME"].to_s, :password => ENV["BASICAUTH_PASSWORD"].to_s
  protect_from_forgery
  layout proc {|controller| controller.request.xhr? ? false : "application" }
end