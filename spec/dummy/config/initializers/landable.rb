Landable.configure do |config|
  config.api_namespace = '/api'
  config.cors.origins  = ['http://cors.test']

  Landable::Engine.routes.default_url_options = { host: 'test.landable.dev' }
  config.sitemap_exclude_categories = %w(Testing)
  config.sitemap_protocol = 'https'
  config.sitemap_additional_paths = %w(/terms.html)
end
