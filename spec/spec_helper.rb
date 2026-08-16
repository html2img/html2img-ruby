# frozen_string_literal: true

require "html2img/client"
require "html2img/cli"

require_relative "support/fake_transport"

RSpec.configure do |config|
  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }
  config.mock_with(:rspec) { |mocks| mocks.verify_partial_doubles = true }
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand(config.seed)

  # Every spec drives the client through a fake transport, so the suite never
  # touches the network and never spends a credit. A stray HTML2IMG_API_KEY in
  # the environment must not change any outcome either.
  config.before do
    Html2img.reset!
    ENV.delete("HTML2IMG_API_KEY")
    ENV.delete("HTML2IMG_BASE_URI")
  end

  config.after { Html2img.reset! }
end
