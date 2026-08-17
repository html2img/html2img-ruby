# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "rails"
require "rails/generators"
require "stringio"
require "tmpdir"
require "generators/html2img/install/install_generator"

RSpec.describe Html2img::Generators::InstallGenerator do
  subject(:initializer) { generate }

  let(:destination) { Dir.mktmpdir }
  let(:initializer_path) { File.join(destination, "config/initializers/html2img.rb") }

  after { FileUtils.remove_entry(destination) }

  # The generator writes to $stdout through Thor; keep the spec output clean.
  def generate
    original = $stdout
    $stdout = StringIO.new

    described_class.start([], destination_root: destination)

    File.read(initializer_path)
  ensure
    $stdout = original
  end

  it "writes an initializer" do
    generate

    expect(File).to exist(initializer_path)
  end

  it "configures the api key from the environment" do
    expect(initializer).to include('config.api_key = ENV.fetch("HTML2IMG_API_KEY", nil)')
  end

  it "produces a valid ruby file" do
    expect { RubyVM::InstructionSequence.compile(initializer) }.not_to raise_error
  end

  it "documents the options it leaves commented out" do
    expect(initializer).to include("# config.timeout", "# config.base_url", "# config.transport")
  end

  it "points at the docs" do
    expect(initializer).to include("https://html2img.com/integrations/ruby/")
  end
end
