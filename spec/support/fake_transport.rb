# frozen_string_literal: true

# Records calls and replays queued responses, standing in for {Html2img::Transport}.
class FakeTransport
  RENDERED = {
    "success" => true,
    "id" => "abc123",
    "url" => "https://i.html2img.com/abc123.png",
    "credits_remaining" => 49
  }.freeze

  attr_reader :calls
  attr_accessor :queued

  def initialize(*responses)
    @queued = responses.empty? ? [[200, RENDERED]] : responses
    @calls = []
  end

  def call(method:, url:, headers:, body:, timeout:)
    @calls << {
      method: method,
      url: url,
      headers: headers,
      body: body.nil? ? nil : JSON.parse(body),
      timeout: timeout
    }

    status, payload = @queued.length > 1 ? @queued.shift : @queued.first

    [status, payload.is_a?(String) ? payload : JSON.generate(payload)]
  end

  def last
    @calls.last
  end

  def count
    @calls.length
  end
end
