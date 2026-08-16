# frozen_string_literal: true

# Capture several URLs concurrently.
#
#   HTML2IMG_API_KEY=your-key ruby examples/batch_screenshots.rb
#
# A render is one HTTP request, so plain threads are enough — the client is
# safe to share between them. Uses one credit per URL.
# https://html2img.com/screenshot-api/

require "html2img/client"

URLS = [
  "https://html2img.com",
  "https://html2img.com/screenshot-api/",
  "https://html2img.com/html-to-pdf/"
].freeze

client = Html2img::Client.new

URLS.map do |url|
  Thread.new do
    response = client.screenshot(url, width: 1280, height: 800, dpi: 2)
    puts "#{url}: #{response.url}"
  rescue Html2img::Error => e
    warn "#{url}: failed (#{e.message})"
  end
end.each(&:join)
