require "reunion/web"
require_relative "organization.rb"

org = Reunion::MyOrganization.new 
app = Reunion::Web::App.new {|a| a.org = org}
run app