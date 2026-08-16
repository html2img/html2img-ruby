# frozen_string_literal: true

require "optparse"
require "json"

require_relative "client"

module Html2img
  # Command line interface, installed as the `html2img` executable.
  #
  #   html2img test
  #   html2img html card.html --width 1200 --height 630 --out card.png
  #   html2img screenshot https://example.com --fullpage --out shot.png
  #   html2img template invoice-image --data '{"number": 1042}'
  class CLI
    TEST_DOCUMENT = <<~HTML.gsub(/\n\s*/, "")
      <!doctype html><html><body style="font-family:system-ui;display:flex;align-items:center;
      justify-content:center;height:180px;margin:0;background:#0f172a;color:#fff">
      <h1>html2img is configured</h1></body></html>
    HTML

    COMMANDS = %w[test html screenshot template].freeze

    RENDER_KEYS = %i[css width height dpi ms_delay wait_for_selector webhook_url fullpage
                     format].freeze

    # @return [Integer] a process exit code
    def self.run(argv, out: $stdout, err: $stderr)
      new(out: out, err: err).run(argv)
    end

    def initialize(out: $stdout, err: $stderr)
      @out = out
      @err = err
      @options = {}
    end

    # @return [Integer] a process exit code
    def run(argv)
      argv = argv.dup
      parser = build_parser
      parser.order!(argv)
      command = argv.shift

      return version if @options[:version]
      return usage(parser) if @options[:help] || command.nil?
      return unknown(command) unless COMMANDS.include?(command)

      parser.parse!(argv)

      execute(command, argv)
    rescue OptionParser::ParseError => e
      fail_with(e.message)
    end

    private

    def execute(command, argv)
      client = Html2img::Client.new(api_key: @options[:api_key], timeout: @options[:timeout])

      report(client, command, dispatch(client, command, argv))
    rescue Html2img::ValidationError => e
      fail_with("Request failed: #{e.message}")
      e.details.each { |field, messages| messages.each { |m| @err.puts("  #{field}: #{m}") } }
      1
    rescue Html2img::Error => e
      fail_with("Request failed: #{e.message}")
    rescue ArgumentError, SystemCallError, JSON::ParserError => e
      fail_with(e.message)
    end

    def dispatch(client, command, argv)
      case command
      when "test"
        client.html(TEST_DOCUMENT, width: 600, height: 200)
      when "html"
        client.html(read_document(argv.shift), **render_options)
      when "screenshot"
        client.screenshot(argument!(argv.shift, "url"), **render_options(screenshot: true))
      when "template"
        client.template(argument!(argv.shift, "slug"), template_data)
      end
    end

    def report(client, command, response)
      @out.puts("Test render succeeded.") if command == "test"

      if response.processing?
        @out.puts("Accepted. The final URL will be delivered to your webhook.")
        return 0
      end

      return fail_with("The API returned no image URL.") if response.url.to_s.empty?

      @out.puts(response.url)
      @out.puts("Saved to #{client.save(response, @options[:out])}") if @options[:out]
      @out.puts("Credits remaining: #{response.credits_remaining}") if response.credits_remaining

      0
    end

    def render_options(screenshot: false)
      keys = screenshot ? RENDER_KEYS + %i[selector] : RENDER_KEYS

      @options.slice(*keys)
    end

    def read_document(source)
      argument!(source, "file")

      source == "-" ? $stdin.read : File.read(source)
    end

    def template_data
      raw = @options[:data]

      return {} if raw.nil?

      raw = $stdin.read if raw == "-"
      raw = File.read(raw.delete_prefix("@")) if raw.start_with?("@")

      parsed = JSON.parse(raw)

      raise ArgumentError, "Template data must be a JSON object." unless parsed.is_a?(Hash)

      parsed
    end

    def argument!(value, name)
      raise ArgumentError, "Missing required argument: #{name}." if value.nil?

      value
    end

    def usage(parser)
      @out.puts(parser.help)
      0
    end

    def version
      @out.puts("html2img #{Html2img::VERSION}")
      0
    end

    def unknown(command)
      fail_with("Unknown command: #{command}. Expected one of: #{COMMANDS.join(", ")}.")
    end

    def fail_with(message)
      @err.puts(message)
      1
    end

    def build_parser
      OptionParser.new do |opts|
        opts.banner = banner
        define_client_options(opts)
        define_render_options(opts)
        define_capture_options(opts)
        define_meta_options(opts)
      end
    end

    def banner
      <<~BANNER
        Render HTML, capture screenshots and export PDFs with html2img.com.

        Usage: html2img <command> [options]

        Commands:
          test              Render a small test image to verify your setup (uses one credit)
          html <file|->     Render an HTML file, or stdin, to an image or PDF
          screenshot <url>  Capture a screenshot of a live URL
          template <slug>   Render a named template

        Options:
      BANNER
    end

    def define_client_options(opts)
      opts.on("--api-key KEY", "API key. Defaults to $HTML2IMG_API_KEY.") do |value|
        @options[:api_key] = value
      end
      opts.on("--timeout SECONDS", Float, "Request timeout (default 35).") do |value|
        @options[:timeout] = value
      end
    end

    def define_render_options(opts)
      opts.on("--width PIXELS", Integer, "Viewport width (1 to 5000).") { |v| @options[:width] = v }
      opts.on("--height PIXELS", Integer, "Viewport height (1 to 5000).") { |v| @options[:height] = v }
      opts.on("--dpi FACTOR", Integer, "Device pixel ratio (1 to 4).") { |v| @options[:dpi] = v }
      opts.on("--fullpage", "Capture the full page height.") { @options[:fullpage] = true }
      opts.on("--format FORMAT", %w[png pdf], "Output format: png or pdf.") { |v| @options[:format] = v }
    end

    def define_capture_options(opts)
      opts.on("--css CSS", "Extra CSS injected after load.") { |v| @options[:css] = v }
      opts.on("--selector SEL", "Crop the capture to this selector.") { |v| @options[:selector] = v }
      opts.on("--ms-delay MS", Integer, "Delay before capture.") { |v| @options[:ms_delay] = v }
      opts.on("--wait-for-selector SEL", "Wait for this selector.") do |value|
        @options[:wait_for_selector] = value
      end
      opts.on("--webhook-url URL", "Deliver the result to this webhook.") do |value|
        @options[:webhook_url] = value
      end
    end

    def define_meta_options(opts)
      opts.on("--data JSON", "Template data: JSON, @file.json, or - for stdin.") do |value|
        @options[:data] = value
      end
      opts.on("-o", "--out PATH", "Also save the render to this path.") { |v| @options[:out] = v }
      opts.on("-v", "--version", "Print the version.") { @options[:version] = true }
      opts.on("-h", "--help", "Print this help.") { @options[:help] = true }
    end
  end
end
