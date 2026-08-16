# frozen_string_literal: true

# Render an Open Graph image for a blog post.
#
#   HTML2IMG_API_KEY=your-key ruby examples/open_graph_image.rb
#
# Uses one credit. https://html2img.com/templates/open-graph-image

require "html2img/client"

CARD = <<~HTML
  <!doctype html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <link rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Inter:wght@400;800&display=swap">
    <style>
      * { margin: 0; box-sizing: border-box; }
      body {
        width: 1200px; height: 630px; padding: 80px;
        display: flex; flex-direction: column; justify-content: space-between;
        font-family: 'Inter', system-ui, sans-serif;
        background: linear-gradient(135deg, #0b1120 0%%, #1e1b4b 100%%);
        color: #f8fafc;
      }
      .brand { font-size: 24px; letter-spacing: .04em; color: #c7d2fe; }
      h1 { font-size: 76px; font-weight: 800; line-height: 1.05; letter-spacing: -.02em; }
      .meta { font-size: 26px; color: #94a3b8; }
    </style>
  </head>
  <body>
    <div class="brand">%<site>s</div>
    <h1>%<title>s</h1>
    <div class="meta">%<author>s &bull; %<date>s</div>
  </body>
  </html>
HTML

client = Html2img::Client.new

response = client.html(
  format(CARD,
         site: "html2img.com",
         title: "How real Chrome rendering changes social images",
         author: "Jamie Rivera",
         date: "16 August 2026"),
  width: 1200,
  height: 630,
  dpi: 2
)

puts response.url
puts "Credits remaining: #{response.credits_remaining}"

client.save(response, "og-image.png")
