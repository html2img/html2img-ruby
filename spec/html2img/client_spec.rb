# frozen_string_literal: true

require "spec_helper"

RSpec.describe Html2img::Client do
  subject(:client) { described_class.new(api_key: "test-key", transport: transport) }

  let(:transport) { FakeTransport.new }

  describe "configuration" do
    it "reads the api key from the environment" do
      ENV["HTML2IMG_API_KEY"] = "from-env"
      Html2img.reset!

      expect { described_class.new }.not_to raise_error
    end

    it "refuses to build without a key" do
      expect { described_class.new }.to raise_error(ArgumentError, /HTML2IMG_API_KEY/)
    end

    it "defaults the base url and timeout" do
      expect(client.base_url).to eq("https://app.html2img.com")
      expect(client.timeout).to eq(35.0)
    end

    it "reads the base url from the environment" do
      ENV["HTML2IMG_BASE_URI"] = "https://example.test/"
      Html2img.reset!

      expect(described_class.new(api_key: "k").base_url).to eq("https://example.test")
    end

    it "trims trailing slashes from the base url" do
      instance = described_class.new(api_key: "k", base_url: "https://example.test//")

      expect(instance.base_url).to eq("https://example.test")
    end

    it "rejects a non-positive timeout" do
      expect { described_class.new(api_key: "k", timeout: 0) }
        .to raise_error(ArgumentError, /positive/)
    end

    it "takes its defaults from Html2img.configure" do
      Html2img.configure do |config|
        config.api_key = "configured"
        config.timeout = 12
      end

      expect(described_class.new.timeout).to eq(12.0)
    end
  end

  describe "#html" do
    it "posts to the html endpoint" do
      client.html("<h1>Hi</h1>")

      expect(transport.last[:method]).to eq("POST")
      expect(transport.last[:url]).to eq("https://app.html2img.com/api/html")
      expect(transport.last[:body]).to eq({ "html" => "<h1>Hi</h1>" })
    end

    it "sends the authentication and content headers" do
      client.html("<h1>Hi</h1>")

      headers = transport.last[:headers]

      expect(headers["X-API-Key"]).to eq("test-key")
      expect(headers["Accept"]).to eq("application/json")
      expect(headers["Content-Type"]).to eq("application/json")
      expect(headers["User-Agent"]).to start_with("html2img-ruby/")
    end

    it "passes every render option through" do
      client.html(
        "<h1>Hi</h1>",
        css: "body { margin: 0 }", width: 1200, height: 630, dpi: 2, fullpage: true,
        ms_delay: 250, wait_for_selector: "#ready", webhook_url: "https://example.test/hook",
        format: "pdf", scale_to_fit: true
      )

      expect(transport.last[:body]).to eq(
        "html" => "<h1>Hi</h1>", "css" => "body { margin: 0 }", "width" => 1200,
        "height" => 630, "dpi" => 2, "fullpage" => true, "ms_delay" => 250,
        "wait_for_selector" => "#ready", "webhook_url" => "https://example.test/hook",
        "format" => "pdf", "scale_to_fit" => true
      )
    end

    it "omits options that were not given" do
      client.html("<h1>Hi</h1>", width: 800)

      expect(transport.last[:body].keys).to contain_exactly("html", "width")
    end

    it "keeps a false flag" do
      client.html("<h1>Hi</h1>", fullpage: false)

      expect(transport.last[:body]["fullpage"]).to be(false)
    end

    it "returns a parsed response" do
      response = client.html("<h1>Hi</h1>")

      expect(response).to have_attributes(
        success?: true,
        id: "abc123",
        url: "https://i.html2img.com/abc123.png",
        credits_remaining: 49,
        processing?: false
      )
    end

    it "rejects an unknown option before sending anything" do
      expect { client.html("<h1>Hi</h1>", widht: 1200) }
        .to raise_error(ArgumentError, /Unknown option\(s\): widht/)

      expect(transport.count).to eq(0)
    end

    it "rejects an empty document" do
      expect { client.html("") }.to raise_error(ArgumentError, /must not be empty/)
    end

    it "rejects an out of range width" do
      expect { client.html("<h1>Hi</h1>", width: 5001) }
        .to raise_error(ArgumentError, /between 1 and 5000/)
    end

    it "rejects an out of range dpi" do
      expect { client.html("<h1>Hi</h1>", dpi: 5) }.to raise_error(ArgumentError, /between 1 and 4/)
    end

    it "rejects an unknown format" do
      expect { client.html("<h1>Hi</h1>", format: "webp") }
        .to raise_error(ArgumentError, /must be one of/)
    end

    it "accepts a format given as a symbol" do
      client.html("<h1>Hi</h1>", format: :pdf)

      expect(transport.last[:body]["format"]).to eq("pdf")
    end
  end

  describe "#screenshot" do
    it "posts to the screenshot endpoint with the selector" do
      client.screenshot("https://example.com", selector: "#hero", fullpage: true)

      expect(transport.last[:url]).to eq("https://app.html2img.com/api/screenshot")
      expect(transport.last[:body]).to eq(
        "url" => "https://example.com", "selector" => "#hero", "fullpage" => true
      )
    end

    it "rejects an empty url" do
      expect { client.screenshot("") }.to raise_error(ArgumentError, /must not be empty/)
    end
  end

  describe "#template" do
    it "posts to the slugged template endpoint" do
      client.template("invoice-image", { "number" => 1042 })

      expect(transport.last[:url]).to eq("https://app.html2img.com/api/v1/templates/invoice-image")
      expect(transport.last[:body]).to eq({ "number" => 1042 })
    end

    it "accepts keyword data" do
      client.template("invoice-image", number: 1042, amount: "£240.00")

      expect(transport.last[:body]).to eq({ "number" => 1042, "amount" => "£240.00" })
    end

    it "url encodes the slug" do
      client.template("weird/slug")

      expect(transport.last[:url]).to end_with("/api/v1/templates/weird%2Fslug")
    end

    it "rejects an empty slug" do
      expect { client.template("") }.to raise_error(ArgumentError, /slug/)
    end
  end

  describe "#download and #save" do
    it "downloads the rendered bytes" do
      response = client.html("<h1>Hi</h1>")
      transport.queued = [[200, "PNG-bytes"]]

      expect(client.download(response)).to eq("PNG-bytes")
      expect(transport.last[:method]).to eq("GET")
    end

    it "downloads from a plain url" do
      transport.queued = [[200, "bytes"]]

      expect(client.download("https://i.html2img.com/x.png")).to eq("bytes")
      expect(transport.last[:url]).to eq("https://i.html2img.com/x.png")
    end

    it "saves a render to disk, creating directories" do
      require "tmpdir"

      response = client.html("<h1>Hi</h1>")
      transport.queued = [[200, "png"]]

      Dir.mktmpdir do |dir|
        path = File.join(dir, "nested", "card.png")

        expect(client.save(response, path)).to eq(path)
        expect(File.binread(path)).to eq("png")
      end
    end

    it "refuses to download a processing render" do
      response = Html2img::RenderResponse.from_hash({ "status" => "processing" })

      expect { client.download(response) }.to raise_error(Html2img::Error, /no image URL yet/)
    end

    it "raises when the download fails" do
      transport.queued = [[404, "nope"]]

      expect { client.download("https://i.html2img.com/x.png") }
        .to raise_error(Html2img::Error, /HTTP 404/)
    end
  end

  describe "module-level shortcuts" do
    it "delegates to a configured default client" do
      Html2img.configure do |config|
        config.api_key = "configured"
        config.transport = transport
      end

      expect(Html2img.html("<h1>Hi</h1>").url).to eq("https://i.html2img.com/abc123.png")
      expect(transport.last[:headers]["X-API-Key"]).to eq("configured")
    end
  end
end
