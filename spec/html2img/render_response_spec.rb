# frozen_string_literal: true

require "spec_helper"

RSpec.describe Html2img::RenderResponse do
  it "parses a synchronous envelope" do
    response = described_class.from_hash(
      "success" => true,
      "id" => "abc123",
      "url" => "https://i.html2img.com/abc123.png",
      "expires_at" => "2026-08-23T10:00:00Z",
      "credits_remaining" => 49
    )

    expect(response).to have_attributes(
      success?: true,
      id: "abc123",
      url: "https://i.html2img.com/abc123.png",
      expires_at: "2026-08-23T10:00:00Z",
      credits_remaining: 49,
      processing?: false
    )
  end

  it "parses an async acceptance envelope" do
    response = described_class.from_hash("success" => true, "status" => "processing")

    expect(response.processing?).to be(true)
    expect(response.url).to be_nil
  end

  it "keeps the raw payload" do
    response = described_class.from_hash("success" => true, "extra" => { "nested" => 1 })

    expect(response.raw["extra"]).to eq({ "nested" => 1 })
  end

  it "tolerates an empty payload" do
    response = described_class.from_hash({})

    expect(response).to have_attributes(success?: false, url: nil, credits_remaining: nil)
  end

  it "detects a pdf render" do
    expect(described_class.from_hash("url" => "https://i.html2img.com/a.pdf").pdf?).to be(true)
    expect(described_class.from_hash("url" => "https://i.html2img.com/a.png").pdf?).to be(false)
  end

  it "stringifies to its url" do
    response = described_class.from_hash("url" => "https://i.html2img.com/a.png")

    expect("#{response}").to eq("https://i.html2img.com/a.png") # rubocop:disable Style/RedundantInterpolation
  end

  it "is frozen" do
    expect(described_class.from_hash({})).to be_frozen
  end
end
