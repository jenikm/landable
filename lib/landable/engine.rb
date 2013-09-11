require "rack/cors"
require "active_model_serializers"
require "carrierwave"
require "rake"

module Landable
  class Engine < ::Rails::Engine
    isolate_namespace Landable

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_girl, :dir => 'spec/factories'
    end

    initializer "landable.enable_cors" do |app|
      config = Landable.configuration
      if config.cors.enabled?
        app.middleware.use Rack::Cors do
          allow do
            origins config.cors.origins
            resource "#{config.api_namespace}/*", methods: [:get, :post, :put, :patch, :delete],
              headers: :any,
              credentials: false,
              max_age: 15.minutes
          end
        end
      end
    end

    initializer "landable.json_schema" do |app|
      if ENV['LANDABLE_VALIDATE_JSON']
        require 'rack/schema'
        app.middleware.use Rack::Schema
      end
    end

    initializer "landable.seed" do |app|
      def seed_required
        Rake::Task['landable:seed:required'].invoke
      end

      if ActiveRecord::Base.connection.schema_exists? 'landable'
        begin
          seed_required
        rescue RuntimeError
          app.load_tasks
          seed_required
        end
      end
    end
  end
end
