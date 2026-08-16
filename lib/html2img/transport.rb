# frozen_string_literal: true

require "net/http"
require "openssl"
require "uri"

module Html2img
  # HTTP transport for the client.
  #
  # The default is built on Net::HTTP from the standard library, so the gem has
  # no runtime dependencies. Anything responding to #call with the same
  # signature can be passed to {Client} as `transport:`, which is the seam for
  # Faraday, HTTPX, a proxy, retry middleware, or a stub in your tests.
  #
  # A transport returns the raw [status, body] pair for *any* HTTP response,
  # including 4xx and 5xx. Mapping a status onto a typed error is the client's
  # job. A transport only raises when no response was received at all.
  class Transport
    # @param method [String] "POST" or "GET"
    # @param url [String] the absolute URL
    # @param headers [Hash{String => String}]
    # @param body [String, nil] the request body
    # @param timeout [Float] seconds
    # @return [Array(Integer, String)] status and body
    def call(method:, url:, headers:, body:, timeout:)
      uri = URI.parse(url)
      request = build_request(method, uri, headers, body)

      response = http(uri, timeout).request(request)

      [response.code.to_i, response.body.to_s]
    # Net::OpenTimeout and Net::ReadTimeout both descend from Timeout::Error.
    rescue Timeout::Error => e
      raise TimeoutError, "The request to #{url} timed out after #{timeout} seconds: #{e.message}"
    rescue SocketError, SystemCallError, OpenSSL::SSL::SSLError, IOError, Net::HTTPBadResponse => e
      raise ConnectionError, "Could not reach the html2img API: #{e.message}"
    end

    private

    def http(uri, timeout)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = timeout
      http.read_timeout = timeout
      http.write_timeout = timeout if http.respond_to?(:write_timeout=)
      http
    end

    def build_request(method, uri, headers, body)
      request =
        case method.to_s.upcase
        when "POST" then Net::HTTP::Post.new(uri)
        when "GET" then Net::HTTP::Get.new(uri)
        else raise ArgumentError, "Unsupported HTTP method: #{method}"
        end

      headers.each { |name, value| request[name] = value }
      request.body = body if body

      request
    end
  end
end
