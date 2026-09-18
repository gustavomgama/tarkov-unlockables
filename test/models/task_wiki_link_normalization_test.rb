# frozen_string_literal: true

require "test_helper"

class TaskWikiLinkNormalizationTest < ActiveSupport::TestCase
  # raw wiki_link => what is persisted after the normalizer runs.
  NORMALIZATION_CASES = {
    "javascript:alert(1)" => nil,
    "data:text/html,<script>alert(1)</script>" => nil,
    "https://escapefromtarkov.fandom.com/wiki/Test" => "https://escapefromtarkov.fandom.com/wiki/Test",
    "http://example.com/page" => "http://example.com/page",
    nil => nil
  }.freeze

  test "normalizes wiki_link to an http(s) URL or nil on save" do
    NORMALIZATION_CASES.each do |raw, expected|
      task = create_task("Wiki Link Task", "wiki-link-task")
      task.wiki_link = raw

      assert task.save, "expected #{raw.inspect} to save"

      if expected.nil?
        assert_nil task.reload.wiki_link, raw.inspect
      else
        assert_equal expected, task.reload.wiki_link, raw.inspect
      end
    end
  end
end
