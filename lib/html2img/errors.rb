# frozen_string_literal: true

module Html2img
  # Base type for every error raised by the client at request time.
  #
  # Rescuing this single type is enough to handle any failure originating from
  # the gem. No raw Net::HTTP exception is ever allowed to escape the public
  # API. Invalid arguments are reported before any request is sent, as a plain
  # ArgumentError.
  class Error < StandardError
    # @return [Integer, nil] the HTTP status, when the failure came from a response
    attr_reader :status_code

    # @return [String, nil] the machine-readable `code` from the API body
    attr_reader :error_code

    # @return [Hash] the decoded JSON response body, when available
    attr_reader :payload

    def initialize(message, status_code: nil, payload: {}, error_code: nil)
      super(message)
      @status_code = status_code
      @payload = payload || {}
      @error_code = error_code
    end

    # The message with the API's error code appended, when there is one.
    def to_s
      error_code ? "#{super} (#{error_code})" : super
    end
  end

  # Raised on a 401: the API key is missing or not recognised.
  # The API `code` is `missing_api_key` or `invalid_api_key`.
  class AuthenticationError < Error; end

  # Raised on a 402: authenticated, but out of credits for the period.
  # The API `code` is `insufficient_credits`.
  class InsufficientCreditsError < Error
    # @return [Integer, nil] credits left on the account. Zero on a 402.
    def credits_remaining
      value = payload["credits_remaining"]

      value.is_a?(Integer) ? value : nil
    end
  end

  # Raised on a 403: the key is valid but the account has no active subscription.
  # The API `code` is `not_subscribed`.
  class NotSubscribedError < Error; end

  # Raised on a 404, for example when a template slug does not exist.
  # The API `code` is `template_not_found`.
  class NotFoundError < Error; end

  # Raised on a 400 or 422 when one or more request fields fail validation.
  # The API `code` is `validation_error`.
  class ValidationError < Error
    # @return [Hash{String => Array<String>}] per-field validation messages
    attr_reader :details

    def initialize(message, details: {}, **options)
      super(message, **options)
      @details = details || {}
    end
  end

  # Raised on a 429: too many requests, or a plan quota was exceeded.
  class RateLimitError < Error
    # @return [Integer, nil] seconds to wait before retrying, when supplied
    def retry_after
      value = payload["retry_after"]

      value.is_a?(Integer) ? value : nil
    end
  end

  # Raised on a 408 or 504, or when the local timeout elapses.
  #
  # The API `code` is `timeout_error` or `api_timeout_error`. For captures that
  # routinely take this long, pass a `webhook_url` to switch to asynchronous
  # delivery.
  class TimeoutError < Error; end

  # Raised on a 5xx when the renderer returns an unexpected error.
  # The API `code` is `service_error`.
  class ServerError < Error; end

  # Raised when the request never reaches a response: DNS failure, refused
  # connection or a TLS error.
  class ConnectionError < Error; end
end
