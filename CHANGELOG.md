# Changelog

All notable changes to `html2img-client` are documented here. This project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) and the
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

## [Unreleased]

## [1.0.0] - 2026-08-16

Initial release of the official Ruby client for the
[HTML to Image API](https://html2img.com).

### Added

- `Html2img::Client` with `#html`, `#screenshot` and `#template`.
- `Html2img.configure` for process-wide defaults, plus module-level shortcuts
  (`Html2img.html`, `.screenshot`, `.template`, `.download`, `.save`).
- `Html2img::RenderResponse`, a frozen value object covering both the
  synchronous and the async acceptance envelopes, with `#processing?`, `#pdf?`
  and the full `#raw` payload.
- PDF output through `format: "pdf"`, including `scale_to_fit`, via the
  [HTML to PDF API](https://html2img.com/html-to-pdf/).
- `#download` and `#save` for keeping a copy of a render.
- Typed error hierarchy rooted at `Html2img::Error`, mapped from the API's
  status codes and `code` field.
- Local validation of every render option, so a typo or an out-of-range value
  raises an `ArgumentError` before a credit is spent.
- Pluggable transports: the default is built on Net::HTTP, and any object
  responding to `#call` can replace it.
- An `html2img` executable with `test`, `html`, `screenshot` and `template`.

[Unreleased]: https://github.com/html2img/html2img-ruby/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/html2img/html2img-ruby/releases/tag/v1.0.0
