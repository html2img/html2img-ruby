# frozen_string_literal: true

require "json"

require_relative "version"
require_relative "errors"
require_relative "configuration"
require_relative "request"
require_relative "render_response"
require_relative "transport"

module Html2img
  # Client for the html2img.com API.
  #
  # Render HTML documents you control, capture live URLs, or render named
  # templates, each returning a {RenderResponse}. Every failure surfaces as an
  # {Html2img::Error}; no raw Net::HTTP exception escapes.
  #
  #   client = Html2img::Client.new           # reads HTML2IMG_API_KEY
  #   response = client.html("<h1>Hello</h1>", width: 1200, height: 630)
  #   response.url # => "https://i.html2img.com/abc123.png"
  #
  # A client is cheap to build and safe to share between threads.
  class Client
    HTML_PATH = "/api/html"
    SCREENSHOT_PATH = "/api/screenshot"
    TEMPLATE_PATH = "/api/v1/templates"

    # @return [String] the API base URL in use
    attr_reader :base_url

    # @return [Float] the per-request timeout in seconds
    attr_reader :timeout

    # @param api_key [String, nil] defaults to {Html2img.configuration}, which
    #   itself defaults to the HTML2IMG_API_KEY environment variable
    # @param base_url [String, nil] override only for testing or a private deployment
    # @param timeout [Numeric, nil] request timeout in seconds
    # @param transport [#call, nil] see {Transport}
    def initialize(api_key: nil, base_url: nil, timeout: nil, transport: nil)
      config = Html2img.configuration

      @api_key = resolve_api_key(api_key || config.api_key)
      @base_url = resolve_base_url(base_url || config.base_url)
      @timeout = resolve_timeout(timeout || config.timeout)
      @transport = transport || config.transport || Transport.new
    end

    # Render an HTML document to an image or PDF (POST /api/html).
    #
    #   client.html(document, width: 1200, height: 630, dpi: 2)
    #   client.html(document, format: "pdf")
    #
    # @param html [String] a complete HTML document
    # @return [RenderResponse]
    # @raise [Html2img::Error] on any API or transport failure
    def html(html, **options)
      post(HTML_PATH, Request.html_body(html, options))
    end

    # Capture a screenshot of a live URL (POST /api/screenshot).
    #
    #   client.screenshot("https://example.com", fullpage: true, selector: "#hero")
    #
    # @param url [String] a publicly reachable URL
    # @return [RenderResponse]
    # @raise [Html2img::Error] on any API or transport failure
    def screenshot(url, **options)
      post(SCREENSHOT_PATH, Request.screenshot_body(url, options))
    end

    # Render a named template from a data payload.
    #
    #   client.template("invoice-image", number: 1042, amount: "£240.00")
    #   client.template("invoice-image", { "number" => 1042 })
    #
    # The data is validated server-side per template. Templates output PNG only.
    #
    # @param slug [String] the template slug, for example "invoice-image"
    # @param data [Hash] template data
    # @param fields [Hash] template data as keyword arguments, merged over data
    # @return [RenderResponse]
    # @raise [Html2img::Error] on any API or transport failure
    def template(slug, data = {}, **fields)
      Request.required_string!("slug", slug)

      post("#{TEMPLATE_PATH}/#{encode(slug)}", data.merge(fields))
    end

    # Download the rendered bytes from a render's CDN URL.
    #
    # @param image [RenderResponse, String] a response or a URL
    # @return [String] the binary body
    # @raise [Html2img::Error] if the render has no URL yet, or the download fails
    def download(image)
      url = url_for(image)

      status, body = @transport.call(
        method: "GET",
        url: url,
        headers: { "Accept" => "*/*", "User-Agent" => user_agent },
        body: nil,
        timeout: timeout
      )

      if status >= 400
        raise Error.new("Could not download the render from #{url}: HTTP #{status}.",
                        status_code: status)
      end

      body
    end

    # Download a render and write it to a local file.
    #
    # Parent directories are created for you.
    #
    #   client.save(response, "og/post-42.png")
    #
    # @return [String] the path written
    # @raise [Html2img::Error] if the render has no URL yet, or the download fails
    def save(image, path)
      require "fileutils"

      contents = download(image)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, contents)

      path
    end

    def inspect
      "#<Html2img::Client base_url=#{base_url.inspect} timeout=#{timeout.inspect}>"
    end

    private

    def post(path, body)
      status, raw = @transport.call(
        method: "POST",
        url: "#{base_url}#{path}",
        headers: headers,
        body: JSON.generate(body),
        timeout: timeout
      )

      payload = decode(raw)

      raise error_for(status, payload) if status >= 400

      RenderResponse.from_hash(payload)
    end

    def headers
      {
        "X-API-Key" => @api_key,
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "User-Agent" => user_agent
      }
    end

    def user_agent
      "html2img-ruby/#{Html2img::VERSION}"
    end

    def encode(slug)
      require "erb"

      ERB::Util.url_encode(slug)
    end

    def decode(body)
      return {} if body.nil? || body.empty?

      parsed = JSON.parse(body)

      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      {}
    end

    def url_for(image)
      return Request.required_string!("image url", image) if image.is_a?(String)

      unless image.respond_to?(:url)
        raise ArgumentError, "Expected a RenderResponse or a URL String, got #{image.class}."
      end

      if image.url.nil? || image.url.empty?
        raise Error, "The render has no image URL yet. Async jobs deliver their URL to the " \
                     "configured webhook."
      end

      image.url
    end

    def resolve_api_key(key)
      if key.nil? || key.to_s.empty?
        raise ArgumentError,
              "No html2img API key. Pass api_key:, set Html2img.configure, or set the " \
              "HTML2IMG_API_KEY environment variable. Create a free key at " \
              "https://app.html2img.com/register."
      end

      key.to_s
    end

    def resolve_base_url(value)
      (value || DEFAULT_BASE_URL).to_s.sub(%r{/+\z}, "")
    end

    def resolve_timeout(value)
      timeout = Float(value || DEFAULT_TIMEOUT)

      raise ArgumentError, "The timeout must be positive, got #{value}." unless timeout.positive?

      timeout
    rescue TypeError, ArgumentError => e
      raise ArgumentError, e.message
    end

    # The exception class for each status the API documents.
    ERRORS = {
      400 => ValidationError,
      401 => AuthenticationError,
      402 => InsufficientCreditsError,
      403 => NotSubscribedError,
      404 => NotFoundError,
      408 => TimeoutError,
      422 => ValidationError,
      429 => RateLimitError,
      504 => TimeoutError
    }.freeze
    private_constant :ERRORS

    def error_for(status, payload)
      kind = ERRORS[status] || (status >= 500 ? ServerError : Error)
      options = {
        status_code: status,
        payload: payload,
        error_code: (payload["code"] if payload["code"].is_a?(String))
      }

      return kind.new(message_from(payload, status), details: details_from(payload), **options) if
        kind == ValidationError

      kind.new(message_from(payload, status), **options)
    end

    def message_from(payload, status)
      %w[error message].each do |key|
        value = payload[key]

        return value if value.is_a?(String) && !value.empty?
      end

      "The html2img API returned HTTP #{status}."
    end

    def details_from(payload)
      details = payload["details"]

      return {} unless details.is_a?(Hash)

      details.each_with_object({}) do |(field, messages), result|
        result[field.to_s] = Array(messages).map(&:to_s)
      end
    end
  end
end

# Rails applications get the Railtie for free: config.html2img.* in any
# environment file, and `rails generate html2img:install`.
require_relative "railtie" if defined?(Rails::Railtie)
