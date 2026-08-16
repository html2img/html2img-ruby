# frozen_string_literal: true

# Official Ruby client for the html2img.com HTML to Image API.
#
# See {Html2img::Client} for the API surface, and {Html2img.configure} for
# process-wide defaults.
module Html2img
  # Base URL of the API. Override only for testing or a private deployment.
  DEFAULT_BASE_URL = "https://app.html2img.com"

  # Request timeout in seconds, just over the 30 second synchronous render budget.
  DEFAULT_TIMEOUT = 35.0

  # Process-wide defaults, for applications that would rather configure once
  # than pass a client around.
  #
  #   Html2img.configure do |config|
  #     config.api_key = ENV.fetch("HTML2IMG_API_KEY")
  #     config.timeout = 45
  #   end
  #
  # In a Rails app this belongs in an initializer.
  class Configuration
    # @return [String, nil] sent as the `X-API-Key` header
    attr_accessor :api_key

    # @return [String] the API base URL
    attr_accessor :base_url

    # @return [Float] request timeout in seconds
    attr_accessor :timeout

    # @return [#call, nil] a custom transport, see {Transport}
    attr_accessor :transport

    def initialize
      @api_key = ENV.fetch("HTML2IMG_API_KEY", nil)
      @base_url = ENV.fetch("HTML2IMG_BASE_URI", nil) || DEFAULT_BASE_URL
      @timeout = DEFAULT_TIMEOUT
      @transport = nil
    end
  end

  class << self
    # The process-wide configuration.
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure the defaults used by {Html2img.client}.
    #
    # @yieldparam config [Configuration]
    def configure
      yield(configuration) if block_given?

      # A reconfigured process should not keep handing out the old client.
      @client = nil

      configuration
    end

    # A memoised client built from {configuration}.
    def client
      @client ||= Client.new
    end

    # Forget the configuration and the memoised client. Mostly for tests.
    def reset!
      @configuration = nil
      @client = nil
    end

    # Render an HTML document with the default client.
    def html(...)
      client.html(...)
    end

    # Capture a screenshot with the default client.
    def screenshot(...)
      client.screenshot(...)
    end

    # Render a named template with the default client.
    def template(...)
      client.template(...)
    end

    # Download a render with the default client.
    def download(...)
      client.download(...)
    end

    # Save a render to disk with the default client.
    def save(...)
      client.save(...)
    end
  end
end
