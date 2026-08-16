# frozen_string_literal: true

require "rails/railtie"

module Html2img
  # Wires the gem into Rails.
  #
  # Loaded automatically when Rails is present, so a Rails app can configure the
  # client from `config/application.rb` or any environment file:
  #
  #   config.html2img.api_key = Rails.application.credentials.html2img_api_key
  #   config.html2img.timeout = 45
  #
  # Anything left unset falls back to the environment, as usual. This runs
  # before `config/initializers`, so an explicit `Html2img.configure` block in an
  # initializer still wins — run `rails generate html2img:install` to create one.
  class Railtie < ::Rails::Railtie
    config.html2img = ActiveSupport::OrderedOptions.new

    initializer "html2img.configure" do |app|
      options = app.config.html2img

      Html2img.configure do |client|
        client.api_key = options.api_key unless options.api_key.nil?
        client.base_url = options.base_url unless options.base_url.nil?
        client.timeout = options.timeout unless options.timeout.nil?
        client.transport = options.transport unless options.transport.nil?
      end
    end

    generators do
      require "generators/html2img/install/install_generator"
    end
  end
end
