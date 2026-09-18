# frozen_string_literal: true

# The app renders HTML only. A request asking for another format — `.json` in the
# path, `?format=xml`, or an API-style Accept header — otherwise reaches the view
# layer and raises ActionView::MissingTemplate, which every crawler or fuzzer
# that appends a format to a URL sees as a 500. Answer 406 instead.
#
# Turbo requests are allowed through: they carry `text/vnd.turbo-stream.html` in
# their Accept header, and rejecting that would break every link and form.
module HtmlOnly
  extend ActiveSupport::Concern

  included do
    before_action :reject_non_html_format
  end

  private

  def reject_non_html_format
    format = request.format
    # `*/*` is what curl, health checkers and many HTTP clients send by default;
    # it is a wildcard, not a request for a non-HTML format, so it renders HTML.
    return if format.html? || format.turbo_stream? || format.to_s == "*/*"

    head :not_acceptable
  end
end
