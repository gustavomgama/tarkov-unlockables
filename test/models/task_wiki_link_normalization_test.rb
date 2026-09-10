# frozen_string_literal: true

require "test_helper"

class TaskWikiLinkNormalizationTest < ActiveSupport::TestCase
  test "normalizes javascript: URI to nil on save" do
    task = Task.new(bsg_id: "wl1-#{SecureRandom.hex(4)}", full_name: "WL Task", name: "wl-task",
                    given_by: "Prapor", wiki_link: "javascript:alert(1)")
    assert task.save
    assert_nil task.reload.wiki_link
  end

  test "keeps https link as-is" do
    task = Task.new(bsg_id: "wl2-#{SecureRandom.hex(4)}", full_name: "WL Task 2", name: "wl-task-2",
                    given_by: "Prapor", wiki_link: "https://escapefromtarkov.fandom.com/wiki/Test")
    assert task.save
    assert_equal "https://escapefromtarkov.fandom.com/wiki/Test", task.reload.wiki_link
  end

  test "keeps http link as-is" do
    task = Task.new(bsg_id: "wl3-#{SecureRandom.hex(4)}", full_name: "WL Task 3", name: "wl-task-3",
                    given_by: "Prapor", wiki_link: "http://example.com/page")
    assert task.save
    assert_equal "http://example.com/page", task.reload.wiki_link
  end

  test "normalizes data: URI to nil on save" do
    task = Task.new(bsg_id: "wl4-#{SecureRandom.hex(4)}", full_name: "WL Task 4", name: "wl-task-4",
                    given_by: "Prapor", wiki_link: "data:text/html,<script>alert(1)</script>")
    assert task.save
    assert_nil task.reload.wiki_link
  end

  test "allows nil wiki_link" do
    task = Task.new(bsg_id: "wl5-#{SecureRandom.hex(4)}", full_name: "WL Task 5", name: "wl-task-5",
                    given_by: "Prapor", wiki_link: nil)
    assert task.save
    assert_nil task.reload.wiki_link
  end
end
