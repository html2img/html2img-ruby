# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "tmpdir"

RSpec.describe Html2img::CLI do
  subject(:cli) { described_class.new(out: out, err: err) }

  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:transport) { FakeTransport.new }

  before do
    Html2img.configure do |config|
      config.api_key = "test-key"
      config.transport = transport
    end
  end

  it "prints help with no command" do
    expect(cli.run([])).to eq(0)
    expect(out.string).to include("Usage: html2img")
  end

  it "prints the version" do
    expect(cli.run(["--version"])).to eq(0)
    expect(out.string).to include("html2img #{Html2img::VERSION}")
  end

  it "reports an unknown command" do
    expect(cli.run(["frobnicate"])).to eq(1)
    expect(err.string).to include("Unknown command: frobnicate")
  end

  describe "test" do
    it "renders and reports" do
      expect(cli.run(["test"])).to eq(0)
      expect(out.string).to include("Test render succeeded.")
      expect(out.string).to include("https://i.html2img.com/abc123.png")
      expect(out.string).to include("Credits remaining: 49")
      expect(transport.last[:body]["width"]).to eq(600)
    end

    it "fails clearly without an api key" do
      Html2img.reset!

      expect(cli.run(["test"])).to eq(1)
      expect(err.string).to include("HTML2IMG_API_KEY")
    end

    it "reports validation details" do
      transport.queued = [[422, { "error" => "Invalid.",
                                  "details" => { "width" => ["Must be 1 to 5000."] } }]]

      expect(cli.run(["test"])).to eq(1)
      expect(err.string).to include("Invalid.")
      expect(err.string).to include("width: Must be 1 to 5000.")
    end
  end

  describe "html" do
    it "reads a file and passes options" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "card.html")
        File.write(source, "<h1>Hi</h1>")

        expect(cli.run(["html", source, "--width", "1200", "--dpi", "2", "--format", "pdf"])).to eq(0)
        expect(transport.last[:body]).to eq(
          "html" => "<h1>Hi</h1>", "width" => 1200, "dpi" => 2, "format" => "pdf"
        )
      end
    end

    it "reports a missing file" do
      expect(cli.run(["html", "/nope/missing.html"])).to eq(1)
      expect(err.string).to include("No such file")
    end

    it "saves the render when asked" do
      Dir.mktmpdir do |dir|
        source = File.join(dir, "card.html")
        target = File.join(dir, "out", "card.png")
        File.write(source, "<h1>Hi</h1>")
        transport.queued = [[200, FakeTransport::RENDERED], [200, "png-bytes"]]

        expect(cli.run(["html", source, "--out", target])).to eq(0)
        expect(File.binread(target)).to eq("png-bytes")
        expect(out.string).to include("Saved to #{target}")
      end
    end
  end

  describe "screenshot" do
    it "passes the selector and fullpage" do
      expect(cli.run(["screenshot", "https://example.com", "--selector", "#hero", "--fullpage"]))
        .to eq(0)
      expect(transport.last[:body]).to eq(
        "url" => "https://example.com", "selector" => "#hero", "fullpage" => true
      )
    end

    it "reports a missing url" do
      expect(cli.run(["screenshot"])).to eq(1)
      expect(err.string).to include("Missing required argument: url")
    end

    it "reports an async acceptance" do
      transport.queued = [[200, { "success" => true, "status" => "processing" }]]

      expect(cli.run(["screenshot", "https://example.com", "--webhook-url", "https://x.test/h"]))
        .to eq(0)
      expect(out.string).to include("delivered to your webhook")
    end
  end

  describe "template" do
    it "sends json data" do
      expect(cli.run(["template", "invoice-image", "--data", '{"number": 7}'])).to eq(0)
      expect(transport.last[:url]).to end_with("/api/v1/templates/invoice-image")
      expect(transport.last[:body]).to eq({ "number" => 7 })
    end

    it "rejects data that is not a json object" do
      expect(cli.run(["template", "invoice-image", "--data", "[1,2]"])).to eq(1)
      expect(err.string).to include("must be a JSON object")
    end
  end
end
