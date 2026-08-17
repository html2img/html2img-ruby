# frozen_string_literal: true

# Configuration for the html2img HTML to Image API.
#
# Docs: https://html2img.com/integrations/ruby/
# Keys: https://app.html2img.com/register

Html2img.configure do |config|
  # Your API key. Keep it out of version control: use an environment variable,
  # or Rails credentials (Rails.application.credentials.html2img_api_key).
  config.api_key = ENV.fetch("HTML2IMG_API_KEY", nil)

  # Request timeout in seconds. The default sits just over the API's 30 second
  # synchronous render budget. For captures that routinely take longer, pass a
  # webhook_url on the request instead of raising this.
  # config.timeout = 35

  # Override only for a private deployment.
  # config.base_url = "https://app.html2img.com"

  # An object responding to #call, for retry middleware, a proxy, or a stub in
  # tests. See https://github.com/html2img/html2img-ruby#custom-transports
  # config.transport = nil
end
