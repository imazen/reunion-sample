require "sinatra"
require "better_errors"

module Reunion
  class OrganizationApp < Sinatra::Base

    set :dump_errors, true

    set :show_exceptions, false

    configure :development do
      use BetterErrors::Middleware
      BetterErrors.application_root = __dir__
    end


    helpers do
      def self.org_cache
        $org ||= Reunion::OrganizationCache.new do
          Reunion::MyOrganization.new
        end

      end 

      def org
        org_cache.org_computed
      end
    end 

    use Reunion::Web::App do |app| 
      app.org_cache = org_cache
    end

    def org_cache
      $org ||= Reunion::OrganizationCache.new do
        Reunion::MyOrganization.new
      end
    end 


    def find_template(views, *a, &b)
      super(views, *a, &b)
      super("#{Reunion::Web::App.views_dir}", *a, &b)
    end
  end
end
