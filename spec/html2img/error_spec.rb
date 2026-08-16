# frozen_string_literal: true

require "spec_helper"

RSpec.describe Html2img::Error do
  def client_for(status, payload)
    Html2img::Client.new(api_key: "k", transport: FakeTransport.new([status, payload]))
  end

  {
    400 => Html2img::ValidationError,
    401 => Html2img::AuthenticationError,
    402 => Html2img::InsufficientCreditsError,
    403 => Html2img::NotSubscribedError,
    404 => Html2img::NotFoundError,
    408 => Html2img::TimeoutError,
    422 => Html2img::ValidationError,
    429 => Html2img::RateLimitError,
    418 => Html2img::Error,
    500 => Html2img::ServerError,
    503 => Html2img::ServerError,
    504 => Html2img::TimeoutError
  }.each do |status, expected|
    it "maps HTTP #{status} onto #{expected}" do
      expect { client_for(status, { "error" => "nope" }).html("<h1>Hi</h1>") }
        .to raise_error(expected)
    end
  end

  it "makes every error rescuable as Html2img::Error" do
    expect { client_for(401, { "error" => "nope" }).html("<h1>Hi</h1>") }
      .to raise_error(Html2img::Error)
  end

  it "surfaces the message, status and code" do
    expect { client_for(401, { "error" => "Invalid API key.", "code" => "invalid_api_key" }).html("x") }
      .to raise_error(Html2img::AuthenticationError) { |error|
        expect(error.message).to eq("Invalid API key. (invalid_api_key)")
        expect(error.status_code).to eq(401)
        expect(error.error_code).to eq("invalid_api_key")
        expect(error.payload["code"]).to eq("invalid_api_key")
      }
  end

  it "falls back to the message field" do
    expect { client_for(500, { "message" => "Renderer exploded." }).html("x") }
      .to raise_error(Html2img::ServerError, /Renderer exploded/)
  end

  it "synthesises a message when the body is empty" do
    expect { client_for(500, {}).html("x") }.to raise_error(Html2img::ServerError, /HTTP 500/)
  end

  it "tolerates a non-json error body" do
    expect { client_for(502, "<html>bad gateway</html>").html("x") }
      .to raise_error(Html2img::ServerError) { |error| expect(error.status_code).to eq(502) }
  end

  it "carries per-field validation details" do
    payload = {
      "error" => "The given data was invalid.",
      "details" => { "width" => ["The width must be between 1 and 5000."], "html" => "Required" }
    }

    expect { client_for(422, payload).html("x") }
      .to raise_error(Html2img::ValidationError) { |error|
        expect(error.details).to eq(
          "width" => ["The width must be between 1 and 5000."],
          "html" => ["Required"]
        )
      }
  end

  it "exposes the remaining balance on a 402" do
    expect { client_for(402, { "error" => "Out of credits.", "credits_remaining" => 0 }).html("x") }
      .to raise_error(Html2img::InsufficientCreditsError) { |error|
        expect(error.credits_remaining).to eq(0)
      }
  end

  it "exposes retry_after on a 429" do
    expect { client_for(429, { "error" => "Slow down.", "retry_after" => 30 }).html("x") }
      .to raise_error(Html2img::RateLimitError) { |error| expect(error.retry_after).to eq(30) }
  end

  describe Html2img::Transport do
    subject(:transport) { described_class.new }

    let(:url) { "https://app.html2img.com/api/html" }

    def call
      transport.call(method: "POST", url: url, headers: {}, body: "{}", timeout: 1.0)
    end

    it "turns a refused connection into a ConnectionError" do
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Errno::ECONNREFUSED)

      expect { call }.to raise_error(Html2img::ConnectionError, /Could not reach/)
    end

    it "turns a dns failure into a ConnectionError" do
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(SocketError, "no such host")

      expect { call }.to raise_error(Html2img::ConnectionError, /no such host/)
    end

    it "turns a read timeout into a TimeoutError" do
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Net::ReadTimeout)

      expect { call }.to raise_error(Html2img::TimeoutError, /timed out/)
    end

    it "lets no raw Net::HTTP error escape" do
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(IOError, "boom")

      expect { call }.to raise_error(Html2img::Error)
    end
  end
end
