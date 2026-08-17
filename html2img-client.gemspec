# frozen_string_literal: true

require_relative "lib/html2img/version"

Gem::Specification.new do |spec|
  spec.name = "html2img-client"
  spec.version = Html2img::VERSION
  spec.authors = ["html2img"]
  spec.email = ["info@html2img.com"]

  spec.summary = "Official Ruby client for the html2img HTML to Image API."
  spec.description = <<~DESC.strip
    Render HTML and CSS to images, capture screenshots of live URLs, render named
    templates and export A4 PDFs, all in real Chrome. Zero runtime dependencies.
  DESC
  spec.homepage = "https://html2img.com"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata = {
    "homepage_uri" => "https://html2img.com",
    "source_code_uri" => "https://github.com/html2img/html2img-ruby",
    "changelog_uri" => "https://github.com/html2img/html2img-ruby/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/html2img/html2img-ruby/issues",
    "documentation_uri" => "https://html2img.com/integrations/ruby/",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir[
    "lib/**/*.rb",
    "exe/*",
    "README.md",
    "CHANGELOG.md",
    "LICENSE"
  ]

  spec.bindir = "exe"
  spec.executables = ["html2img"]
  spec.require_paths = ["lib"]
end
