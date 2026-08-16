# frozen_string_literal: true

require "rails/generators/base"

module Html2img
  module Generators
    # Creates config/initializers/html2img.rb.
    #
    #   rails generate html2img:install
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates an html2img initializer at config/initializers/html2img.rb."

      def copy_initializer
        template "html2img.rb", "config/initializers/html2img.rb"
      end

      def show_readme
        say ""
        say "Set HTML2IMG_API_KEY in your environment, then check it works:", :green
        say "  bin/rails runner 'puts Html2img.html(%q{<h1>Hello</h1>}, width: 600, height: 200).url'"
        say ""
      end
    end
  end
end
