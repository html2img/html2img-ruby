# frozen_string_literal: true

module Html2img
  # The result of a successful render call.
  #
  # Covers both the synchronous envelope (`url` populated) and the asynchronous
  # acceptance envelope returned when a `webhook_url` was supplied (`status` is
  # "processing" and `url` is nil until the webhook fires).
  class RenderResponse
    # @return [Boolean]
    attr_reader :success

    # @return [String, nil] the render id
    attr_reader :id

    # @return [String, nil] the CDN URL of the render
    attr_reader :url

    # @return [String, nil] when a hosted render expires, as an ISO 8601 string.
    #   Nil on paid plans, where renders stay hosted permanently; set on
    #   free-tier renders, which are hosted for seven days.
    attr_reader :expires_at

    # @return [Integer, nil] credits left after this call
    attr_reader :credits_remaining

    # @return [String, nil] "processing" for async jobs
    attr_reader :status

    # @return [String, nil]
    attr_reader :message

    # @return [String, nil] the template slug, when applicable
    attr_reader :template

    # @return [Hash] the full decoded JSON payload
    attr_reader :raw

    # Build a response from a decoded JSON payload.
    def self.from_hash(data)
      data = {} unless data.is_a?(Hash)

      new(
        success: data["success"] ? true : false,
        id: string_or_nil(data["id"]),
        url: string_or_nil(data["url"]),
        expires_at: string_or_nil(data["expires_at"]),
        credits_remaining: integer_or_nil(data["credits_remaining"]),
        status: string_or_nil(data["status"]),
        message: string_or_nil(data["message"]),
        template: string_or_nil(data["template"]),
        raw: data
      )
    end

    def self.string_or_nil(value)
      return nil if value.nil? || value.is_a?(Hash) || value.is_a?(Array)

      value.to_s
    end

    def self.integer_or_nil(value)
      return value if value.is_a?(Integer)
      return value.to_i if value.is_a?(Float)
      return Integer(value, exception: false) if value.is_a?(String)

      nil
    end

    private_class_method :string_or_nil, :integer_or_nil

    def initialize(success: false, id: nil, url: nil, expires_at: nil, credits_remaining: nil,
                   status: nil, message: nil, template: nil, raw: {})
      @success = success
      @id = id
      @url = url
      @expires_at = expires_at
      @credits_remaining = credits_remaining
      @status = status
      @message = message
      @template = template
      @raw = raw
      freeze
    end

    # Whether this is an async job still being rendered.
    #
    # When true, the final URL is delivered to the request's `webhook_url`
    # rather than being available on this response.
    def processing?
      status == "processing"
    end

    # Whether the render came back as a PDF rather than an image.
    def pdf?
      return false if url.nil?

      url.to_s.split("?").first.to_s.downcase.end_with?(".pdf")
    end

    def success?
      success
    end

    # The URL, so a response drops straight into string interpolation.
    def to_s
      url.to_s
    end

    def inspect
      "#<Html2img::RenderResponse url=#{url.inspect} status=#{status.inspect} " \
        "credits_remaining=#{credits_remaining.inspect}>"
    end
  end
end
