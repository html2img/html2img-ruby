[![html2img — HTML to image API, rendered in real Chrome](https://html2img.com/og-image.png)](https://html2img.com)

# html2img for Ruby

[![Gem Version](https://img.shields.io/gem/v/html2img-client)](https://rubygems.org/gems/html2img-client)
[![Downloads](https://img.shields.io/gem/dt/html2img-client)](https://rubygems.org/gems/html2img-client)
[![Ruby](https://img.shields.io/badge/ruby-3.1%20%7C%203.2%20%7C%203.3%20%7C%203.4%20%7C%204.0-CC342D)](https://www.ruby-lang.org)
[![License](https://img.shields.io/github/license/html2img/html2img-ruby)](LICENSE)

The official Ruby client for the [HTML to Image API](https://html2img.com) at html2img.com. Turn HTML and CSS into images, capture screenshots of live URLs, render named templates, and export A4 PDFs, all returning a typed response object.

Every render runs in real Chrome, so flexbox, grid, custom properties, web fonts and inline JavaScript behave exactly as they do in the browser. The gem has **zero runtime dependencies** — it is built on Net::HTTP from the standard library — and works anywhere Ruby does: Rails and Sinatra apps, Sidekiq and Active Job workers, rake tasks and one-off scripts. The full API reference lives in the [documentation](https://html2img.com/docs), with a Ruby guide at [html2img.com/integrations/ruby](https://html2img.com/integrations/ruby/).

Three things this gem does, each with its own worked guide:

- **[HTML to Image API](https://html2img.com/)** — render a document you control into a PNG.
- **[Screenshot API](https://html2img.com/screenshot-api/)** — capture any public URL, full page or cropped to one element.
- **[HTML to PDF API](https://html2img.com/html-to-pdf/)** — the same markup as a vector A4 PDF with selectable text.

## Contents

- [What you can build](#what-you-can-build)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Render HTML](#render-html)
  - [Capture a screenshot](#capture-a-screenshot)
  - [Generate a PDF](#generate-a-pdf)
  - [Render a template](#render-a-template)
- [Saving renders](#saving-renders)
- [Rails](#rails)
- [Background jobs](#background-jobs)
- [Render options](#render-options)
- [The response](#the-response)
- [Asynchronous delivery](#asynchronous-delivery)
- [Error handling](#error-handling)
- [Custom transports](#custom-transports)
- [Command line](#command-line)
- [Verifying your setup](#verifying-your-setup)
- [Other languages and frameworks](#other-languages-and-frameworks)
- [Development](#development)
- [Links](#links)

## What you can build

- **Open Graph and social images**, generated per page or post. See the [Open Graph image template](https://html2img.com/templates/open-graph-image) and [Twitter/X post template](https://html2img.com/templates/twitter-post).
- **Business documents** such as [invoices](https://html2img.com/templates/invoice-image), [receipts](https://html2img.com/templates/receipt-image), [event tickets](https://html2img.com/templates/event-ticket) and [certificates](https://html2img.com/templates/certificate-of-completion) — as PNGs, or as PDFs through the [HTML to PDF API](https://html2img.com/html-to-pdf/).
- **Developer assets** such as [code screenshots](https://html2img.com/templates/code-screenshot) and [GitHub social previews](https://html2img.com/templates/github-social-preview).
- **URL screenshots** through the [Screenshot API](https://html2img.com/screenshot-api/), full page or cropped to a single element, with CSS injection to hide cookie banners and chat widgets before capture.

Browse the [full template library](https://html2img.com/templates), or try the no-signup [browser tools](https://html2img.com/tools) to see the output before you write any code.

## Requirements

- Ruby 3.1 or newer (tested on 3.1, 3.2, 3.3, 3.4 and 4.0)
- An html2img API key, issued per account from your [dashboard](https://app.html2img.com/register)

Every account starts with 50 free credits and no card is needed to get started. Free-tier renders are hosted for seven days; on any paid [plan](https://html2img.com/pricing) they are hosted permanently, including everything you rendered before upgrading.

> **Keep your API key on the server.** This client is designed for server-side use. Shipping your key in client-side code would let anyone spend your credits.

## Installation

```bash
bundle add html2img-client
```

Or in your `Gemfile`:

```ruby
gem "html2img-client"
```

The gem is named `html2img-client`; the namespace is `Html2img`:

```ruby
require "html2img/client"
```

Bundler requires the gem for you in a Rails app, so the `require` is only needed in plain scripts.

Set your API key in the environment. The client reads it automatically:

```dotenv
HTML2IMG_API_KEY=your-api-key
```

See the [authentication docs](https://html2img.com/docs/authentication) for issuing and rotating keys, and the [getting started guide](https://html2img.com/docs/getting-started) for a tour of the API.

## Quick start

```ruby
require "html2img/client"

client = Html2img::Client.new # reads HTML2IMG_API_KEY from the environment

response = client.html(
  "<h1 style='font: 700 64px system-ui'>Hello from Ruby</h1>",
  width: 1200,
  height: 630,
  dpi: 2
)

puts response.url # => "https://i.html2img.com/abc123def456.png"
```

## Configuration

Pass configuration when you build a client:

```ruby
client = Html2img::Client.new(
  api_key: "your-api-key",             # default: ENV["HTML2IMG_API_KEY"]
  base_url: "https://app.html2img.com", # default: ENV["HTML2IMG_BASE_URI"], then this
  timeout: 35                           # seconds
)
```

Or configure the process once and use the module-level shortcuts, which is usually what you want in an application:

```ruby
# config/initializers/html2img.rb
Html2img.configure do |config|
  config.api_key = ENV.fetch("HTML2IMG_API_KEY")
  config.timeout = 45
end

Html2img.html(document, width: 1200, height: 630)
Html2img.screenshot("https://example.com")
Html2img.template("invoice-image", number: 1042)
```

| Variable            | Default                    | Purpose                                                    |
| ------------------- | -------------------------- | ---------------------------------------------------------- |
| `HTML2IMG_API_KEY`  | none                       | Your key, sent as the `X-API-Key` header on every request. |
| `HTML2IMG_BASE_URI` | `https://app.html2img.com` | API base URL. You rarely need to change this.              |

The default timeout of 35 seconds sits just over the 30 second synchronous render budget. For captures likely to exceed it, pass a `webhook_url` on the request rather than raising the timeout — see [asynchronous delivery](#asynchronous-delivery).

A client is cheap to build and safe to share between threads, so a memoised one is fine.

## Usage

Every render method returns an `Html2img::RenderResponse`. Options are keyword arguments, validated locally before anything is sent.

### Render HTML

`POST /api/html`. Send a complete HTML document and get back an image of the rendered result. Inline your CSS in a `<style>` block, or reference remote stylesheets and web fonts with `<link>` tags in the document head. This is the [HTML to Image API](https://html2img.com/); see the [`html` parameter docs](https://html2img.com/docs/parameters/html).

```ruby
response = client.html(
  document,                                          # a complete HTML document
  css: "body { background: #0f172a; color: #fff; }", # injected after load
  width: 1200,
  height: 630,
  dpi: 2                                             # retina
)

response.url # => "https://i.html2img.com/abc123def456.png"
```

### Capture a screenshot

`POST /api/screenshot`. Fetch a public URL in real Chrome and capture it. Use `selector` to crop to a single element, and `css` to hide cookie banners or chat widgets before the capture. This is the [Screenshot API](https://html2img.com/screenshot-api/); see the [`url` parameter docs](https://html2img.com/docs/parameters/url) and the [`selector` docs](https://html2img.com/docs/parameters/selector).

```ruby
response = client.screenshot(
  "https://example.com",
  width: 1200,
  height: 630,
  selector: "#hero",
  css: ".cookie-banner, .intercom-launcher { display: none !important; }",
  dpi: 2
)
```

Full-page captures grow to the whole scroll length of the document:

```ruby
client.screenshot("https://example.com/pricing", fullpage: true)
```

### Generate a PDF

Pass `format: "pdf"` on either render and the result comes back as an A4 portrait vector PDF instead of a PNG: text stays selectable and searchable, web fonts are embedded, and long content paginates automatically. The API ignores `width`, `height`, `dpi`, `fullpage` and `selector` in PDF mode, and the response URL points at a `.pdf` file. One credit, the same as an image. This is the [HTML to PDF API](https://html2img.com/html-to-pdf/); see the [`format` parameter docs](https://html2img.com/docs/parameters/format).

```ruby
response = client.html(invoice_html, format: "pdf")

# Wide content, such as a data table, can be scaled down to the page width
response = client.html(report_html, format: "pdf", scale_to_fit: true)

client.save(response, "invoices/#{invoice.number}.pdf")
```

### Render a template

`POST /api/v1/templates/{slug}`. Render one of the built-in [templates](https://html2img.com/templates) from a data payload, with no markup of your own. The data is validated server-side per template. Templates output PNG only.

```ruby
response = client.template("invoice-image", number: 1042, amount: "£240.00", due_date: "2026-07-01")

# A hash works too, when your data is already one
response = client.template("invoice-image", invoice.as_json)
```

## Saving renders

The API returns the CDN URL of the render rather than the raw bytes, so you can cache and re-serve it from your own infrastructure. When you would rather keep a copy, `download` gives you the bytes and `save` writes them to a path, creating parent directories as needed:

```ruby
response = client.html(document, width: 1200, height: 630)

bytes = client.download(response)              # => String (binary)
path  = client.save(response, "og/post-42.png") # => "og/post-42.png"
```

Both accept a URL string as well as a response, so you can re-download an earlier render:

```ruby
client.save("https://i.html2img.com/abc123.png", "thumbnails/abc123.png")
```

To store somewhere else, hand the bytes to whatever you already use — for example Active Storage:

```ruby
post.og_image.attach(
  io: StringIO.new(client.download(response)),
  filename: "og-#{post.id}.png",
  content_type: "image/png"
)
```

## Rails

The gem detects Rails and loads a Railtie, so there is nothing to require. Generate an initializer:

```bash
bin/rails generate html2img:install
```

That writes a commented `config/initializers/html2img.rb` reading your key from the environment. Or configure it from any environment file instead, which is handy for per-environment settings:

```ruby
# config/environments/production.rb
config.html2img.api_key = Rails.application.credentials.html2img_api_key
config.html2img.timeout = 45
```

Both routes end up at the same place. The Railtie runs before `config/initializers`, so an explicit `Html2img.configure` block wins if you use both.

Render an Action View template into the image, so the card lives with the rest of your views:

```ruby
class OgImage
  def self.for(post)
    html = ApplicationController.render(
      template: "og_images/post",
      layout: false,
      assigns: { post: post }
    )

    Html2img.html(html, width: 1200, height: 630, dpi: 2).url
  end
end
```

Then output it in your layout:

```erb
<meta property="og:image" content="<%= @post.og_image_url %>">
```

## Background jobs

Renders are a natural fit for a background job, especially full-page captures:

```ruby
class GenerateOgImageJob < ApplicationJob
  queue_as :default

  retry_on Html2img::ServerError, Html2img::ConnectionError, wait: :polynomially_longer, attempts: 3
  discard_on Html2img::ValidationError

  def perform(post)
    response = Html2img.html(OgImage.html_for(post), width: 1200, height: 630)

    post.update!(og_image_url: response.url)
  end
end
```

Retrying a `ServerError` or a `ConnectionError` is worthwhile; retrying a `ValidationError` is not, since the same request will fail the same way. For very large captures, prefer [asynchronous delivery](#asynchronous-delivery) over a long-running job.

## Render options

Both renders accept the following. Any option you leave out is omitted from the request, so the server applies its own default. The complete reference is in the [parameter docs](https://html2img.com/docs/parameters).

| Option              | Type            | Docs                                                                                   |
| ------------------- | --------------- | --------------------------------------------------------------------------------------- |
| `css`               | String          | [css](https://html2img.com/docs/parameters/css)                                          |
| `width`             | Integer         | [dimensions](https://html2img.com/docs/parameters/dimensions) (1 to 5000)                |
| `height`            | Integer         | [dimensions](https://html2img.com/docs/parameters/dimensions) (ignored when `fullpage`)  |
| `fullpage`          | Boolean         | [fullpage](https://html2img.com/docs/parameters/fullpage)                                |
| `dpi`               | Integer         | [dpi](https://html2img.com/docs/parameters/dpi) (1 to 4, use 2 for retina)               |
| `webhook_url`       | String          | [webhook_url](https://html2img.com/docs/parameters/webhook-url)                          |
| `ms_delay`          | Integer         | [ms_delay](https://html2img.com/docs/parameters/ms_delay) (1 to 5000)                    |
| `wait_for_selector` | String          | [wait_for_selector](https://html2img.com/docs/parameters/wait_for_selector)              |
| `format`            | String / Symbol | [format](https://html2img.com/docs/parameters/format): `"png"` (default) or `"pdf"`      |
| `scale_to_fit`      | Boolean         | PDF only. Scale wide content down to the page width instead of clipping it.              |

`screenshot` also accepts [`selector`](https://html2img.com/docs/parameters/selector) to crop the capture to a single element. `html` does not, since you control the markup.

Options are checked locally before a request is sent, so a typo or an out-of-range value raises an `ArgumentError` immediately rather than spending a credit on a rejected render:

```ruby
client.html(document, widht: 1200)
# => ArgumentError: Unknown option(s): widht. Valid options are: css, dpi, format, ...

client.html(document, width: 9000)
# => ArgumentError: The width must be between 1 and 5000, got 9000.
```

Custom fonts are loaded by referencing them with `<link>` tags in your HTML document head, or by linking a web font from the page you capture. Everything referenced by your markup is fetched by the renderer over the public internet, so `localhost` URLs will not resolve.

## The response

Every render returns a frozen `Html2img::RenderResponse`:

```ruby
response.success?          # => true
response.id                # => "abc123", the render id
response.url               # => "https://i.html2img.com/abc123.png"
response.expires_at        # => ISO 8601 String, or nil on paid plans
response.credits_remaining # => Integer, credits left after this call
response.status            # => "processing" for async jobs
response.message           # => String or nil
response.template          # => the template slug, when applicable
response.processing?       # => false
response.pdf?              # => false
response.raw               # => the full decoded JSON payload
```

`to_s` is the URL, so a response drops straight into string interpolation or a view.

## Asynchronous delivery

Synchronous requests have a 30 second budget. For captures likely to exceed it, pass a `webhook_url`. The API responds immediately with `status: "processing"` and no URL, then POSTs the final URL to your endpoint once rendering finishes. See the [`webhook_url` docs](https://html2img.com/docs/parameters/webhook-url).

```ruby
response = client.screenshot(
  "https://example.com/long-report",
  fullpage: true,
  webhook_url: hooks_html2img_url
)

if response.processing?
  # the final URL will arrive at your webhook, not on this response
end
```

## Error handling

Every request-time failure raises an `Html2img::Error` or one of its subclasses. Rescue that single type to handle any error, or rescue a specific subclass. No raw Net::HTTP exception escapes the gem. Invalid arguments are reported before any request is sent, as a plain `ArgumentError`.

```ruby
begin
  response = client.html(document)
rescue Html2img::ValidationError => e
  # 400 or 422: inspect the per-field messages
  e.details.each { |field, messages| logger.warn("#{field}: #{messages.join(', ')}") }
rescue Html2img::InsufficientCreditsError => e
  logger.error("Out of credits: #{e.credits_remaining}")
rescue Html2img::Error => e
  e.status_code # => Integer or nil
  e.error_code  # => String or nil, the API "code" field
  e.payload     # => Hash, the decoded body
end
```

| Exception                          | When                                                            |
| ---------------------------------- | --------------------------------------------------------------- |
| `Html2img::AuthenticationError`     | 401, missing or invalid API key.                                 |
| `Html2img::InsufficientCreditsError`| 402, no credits remaining. Exposes `credits_remaining`.          |
| `Html2img::NotSubscribedError`      | 403, no active subscription.                                     |
| `Html2img::NotFoundError`           | 404, for example an unknown template slug.                       |
| `Html2img::ValidationError`         | 400 or 422, with `details` per field.                            |
| `Html2img::RateLimitError`          | 429, rate or quota exceeded. Exposes `retry_after`.              |
| `Html2img::TimeoutError`            | 408 or 504, or the local timeout elapsed.                        |
| `Html2img::ServerError`             | 5xx, an unexpected renderer error.                               |
| `Html2img::ConnectionError`         | the request never reached a response.                            |
| `Html2img::Error`                   | base type for all of the above.                                  |

Retries are left to you, so that a retry policy fits your application rather than the other way round. A 5xx or a `ConnectionError` is worth retrying; a 4xx is not.

## Custom transports

All HTTP goes through a single object responding to `#call`, which is the seam for retry middleware, proxies, connection pooling and tests. The default is `Html2img::Transport`, built on Net::HTTP. To use Faraday instead:

```ruby
class FaradayTransport
  def initialize(connection) = @connection = connection

  def call(method:, url:, headers:, body:, timeout:)
    response = @connection.run_request(method.downcase.to_sym, url, body, headers) do |request|
      request.options.timeout = timeout
    end

    [response.status, response.body.to_s]
  end
end

client = Html2img::Client.new(transport: FaradayTransport.new(Faraday.new))
```

The client still sends the `X-API-Key`, `Accept` and `Content-Type` headers on every request, and still maps every status onto the same typed errors.

In tests, a transport is the simplest way to avoid the network entirely:

```ruby
transport = ->(**) { [200, '{"success": true, "url": "https://i.html2img.com/test.png"}'] }
client = Html2img::Client.new(api_key: "test", transport: transport)

expect(client.html("<h1>Hi</h1>").url).to eq("https://i.html2img.com/test.png")
```

## Command line

Installing the gem also installs an `html2img` executable:

```bash
html2img test                                              # verify your setup
html2img html card.html --width 1200 --height 630 -o card.png
html2img html - --format pdf -o report.pdf < report.html   # read stdin
html2img screenshot https://example.com --fullpage -o shot.png
html2img screenshot https://example.com --selector "#hero" -o hero.png
html2img template invoice-image --data '{"number": 1042}'
```

Every command prints the resulting URL, and `--out/-o` also saves the render locally. Run `html2img --help` for the full list.

## Verifying your setup

Confirm your key and configuration by rendering a small test image:

```bash
html2img test
```

It prints the resulting image URL and your remaining credits, or a clear error if the key is missing or rejected. The check uses one credit. There is also a [testing guide](https://html2img.com/docs/testing) for the API itself.

## Other languages and frameworks

The same API has worked guides and official packages for
[Python](https://github.com/html2img/html2img-python),
[Django](https://github.com/html2img/html2img-django),
[PHP](https://html2img.com/integrations/php/),
[Laravel](https://html2img.com/integrations/laravel/),
[Ruby on Rails](https://html2img.com/docs/usage/rails),
[JavaScript and Node.js](https://html2img.com/integrations/javascript/),
[React](https://html2img.com/docs/usage/react),
[Vue](https://html2img.com/docs/usage/vue),
[WordPress](https://html2img.com/integrations/wordpress/) and
[Statamic](https://html2img.com/integrations/statamic/).

## Development

```bash
bundle install

bundle exec rspec    # specs, no network and no credits spent
bundle exec rubocop  # lint
bundle exec rake     # both
```

Publishing to RubyGems is covered in [PUBLISHING.md](PUBLISHING.md).

## Links

[HTML to Image API](https://html2img.com) · [Screenshot API](https://html2img.com/screenshot-api/) · [HTML to PDF API](https://html2img.com/html-to-pdf/) · [Documentation](https://html2img.com/docs) · [Ruby guide](https://html2img.com/integrations/ruby/) · [Templates](https://html2img.com/templates) · [Tools](https://html2img.com/tools) · [Features](https://html2img.com/features) · [Comparisons](https://html2img.com/compare) · [Articles](https://html2img.com/articles) · [Pricing](https://html2img.com/pricing)

## Licence

MIT. See [LICENSE](LICENSE).
