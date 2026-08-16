# frozen_string_literal: true

module Html2img
  # Builds and validates the JSON bodies sent to the render endpoints.
  #
  # The range checks mirror the server-side validation rules, so an obvious
  # mistake fails fast with a clear message before a request is sent, and
  # before a credit is spent. Any option left nil is omitted from the body, so
  # the server applies its own default.
  #
  # @api private
  module Request
    MIN_DIMENSION = 1
    MAX_DIMENSION = 5000
    MIN_DPI = 1
    MAX_DPI = 4
    MIN_MS_DELAY = 1
    MAX_MS_DELAY = 5000

    FORMATS = %w[png pdf].freeze

    # Options accepted by both render endpoints.
    COMMON_OPTIONS = %i[
      css width height fullpage dpi webhook_url ms_delay wait_for_selector format scale_to_fit
    ].freeze

    # `selector` crops a screenshot to one element. There is no equivalent for
    # an HTML render, since you control the markup.
    SCREENSHOT_OPTIONS = (COMMON_OPTIONS + %i[selector]).freeze

    module_function

    # Build the body for POST /api/html.
    #
    # @param html [String] a complete HTML document
    # @return [Hash]
    def html_body(html, options)
      validate_keys!(options, COMMON_OPTIONS)

      body = { "html" => required_string!("html", html) }

      body.merge(common(options)).compact
    end

    # Build the body for POST /api/screenshot.
    #
    # @param url [String] a publicly reachable URL
    # @return [Hash]
    def screenshot_body(url, options)
      validate_keys!(options, SCREENSHOT_OPTIONS)

      body = { "url" => required_string!("url", url) }
      body["selector"] = optional_string!("selector", options[:selector])

      body.merge(common(options)).compact
    end

    # The options shared by both endpoints, mapped onto their API field names.
    def common(options)
      {
        "css" => optional_string!("css", options[:css]),
        "width" => dimension!("width", options[:width]),
        "height" => dimension!("height", options[:height]),
        "fullpage" => boolean!("fullpage", options[:fullpage]),
        "dpi" => dpi!(options[:dpi]),
        "webhook_url" => optional_string!("webhook_url", options[:webhook_url]),
        "ms_delay" => ms_delay!(options[:ms_delay]),
        "wait_for_selector" => optional_string!("wait_for_selector", options[:wait_for_selector]),
        "format" => format!(options[:format]),
        "scale_to_fit" => boolean!("scale_to_fit", options[:scale_to_fit])
      }
    end

    def validate_keys!(options, allowed)
      unknown = options.keys - allowed

      return if unknown.empty?

      raise ArgumentError,
            "Unknown option(s): #{unknown.join(", ")}. " \
            "Valid options are: #{allowed.sort.join(", ")}."
    end

    def required_string!(name, value)
      raise ArgumentError, "The #{name} must be a String, got #{value.class}." unless value.is_a?(String)

      raise ArgumentError, "The #{name} must not be empty." if value.empty?

      value
    end

    def optional_string!(name, value)
      return nil if value.nil?

      raise ArgumentError, "The #{name} must be a String, got #{value.class}." unless value.is_a?(String)

      value
    end

    def boolean!(name, value)
      return nil if value.nil?
      return value if [true, false].include?(value)

      raise ArgumentError, "The #{name} must be true or false, got #{value.inspect}."
    end

    def dimension!(name, value)
      integer_in_range!(name, value, MIN_DIMENSION, MAX_DIMENSION)
    end

    def dpi!(value)
      integer_in_range!("dpi", value, MIN_DPI, MAX_DPI)
    end

    def ms_delay!(value)
      integer_in_range!("ms_delay", value, MIN_MS_DELAY, MAX_MS_DELAY)
    end

    def integer_in_range!(name, value, low, high)
      return nil if value.nil?

      raise ArgumentError, "The #{name} must be an Integer, got #{value.class}." unless value.is_a?(Integer)

      unless value.between?(low, high)
        raise ArgumentError, "The #{name} must be between #{low} and #{high}, got #{value}."
      end

      value
    end

    def format!(value)
      return nil if value.nil?

      normalised = value.to_s.downcase

      return normalised if FORMATS.include?(normalised)

      raise ArgumentError, "The format must be one of: #{FORMATS.join(", ")}. Got #{value.inspect}."
    end
  end
end
