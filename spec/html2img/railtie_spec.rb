# frozen_string_literal: true

require "spec_helper"
require "rails"
require "html2img/railtie"

RSpec.describe Html2img::Railtie do
  # Run the Railtie's own initializer against a minimal stand-in for the app.
  # Booting a full anonymous Rails::Application would exercise Rails' engine
  # initializers rather than ours, and fails without a filesystem root.
  def boot(**options)
    config = ActiveSupport::OrderedOptions.new
    options.each { |key, value| config[key] = value }

    app_config = Object.new
    app_config.define_singleton_method(:html2img) { config }

    app = Object.new
    app.define_singleton_method(:config) { app_config }

    described_class.initializers.find { |i| i.name == "html2img.configure" }.run(app)
  end

  it "is registered as a Railtie" do
    expect(described_class.ancestors).to include(Rails::Railtie)
  end

  it "exposes a config.html2img namespace" do
    expect(described_class.config.html2img).to be_a(ActiveSupport::OrderedOptions)
  end

  it "applies config.html2img to the client configuration" do
    boot(api_key: "from-rails", timeout: 45, base_url: "https://example.test")

    expect(Html2img.configuration).to have_attributes(
      api_key: "from-rails",
      timeout: 45,
      base_url: "https://example.test"
    )
  end

  it "leaves unset options alone" do
    ENV["HTML2IMG_API_KEY"] = "from-env"
    Html2img.reset!

    boot(timeout: 20)

    expect(Html2img.configuration).to have_attributes(api_key: "from-env", timeout: 20)
  end

  it "passes a transport through" do
    transport = FakeTransport.new

    boot(api_key: "k", transport: transport)

    expect(Html2img.configuration.transport).to be(transport)
  end

  it "registers the install generator" do
    expect(File).to exist(
      File.expand_path("../../lib/generators/html2img/install/install_generator.rb", __dir__)
    )
  end
end
