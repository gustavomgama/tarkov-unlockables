# frozen_string_literal: true

require "test_helper"

# The seed aborts when the import does not match its sources; the counts are
# injected here so both sides are deterministic.
class Importers::IntegrityTest < ActiveSupport::TestCase
  def expected_counts
    {
      task_count: Importers::Integrity.source_size(Importers::TaskGraph::SOURCE),
      item_count: Importers::Integrity.source_size(Importers::Index::SOURCE) { |row| row["bsg_id"].present? }
    }
  end

  test "reports nothing when the import matches the sources" do
    assert_empty Importers::Integrity.problems(**expected_counts, blank_slugs: 0)
  end

  test "reports a task shortfall" do
    problems = Importers::Integrity.problems(**expected_counts.merge(task_count: expected_counts[:task_count] - 51), blank_slugs: 0)

    assert_equal 1, problems.size
    assert_match(/imported \d+ tasks, the source has \d+/, problems.first)
  end

  test "reports an item shortfall" do
    problems = Importers::Integrity.problems(**expected_counts, item_count: expected_counts[:item_count] - 1, blank_slugs: 0)

    assert_match(/items/, problems.first)
  end

  test "reports tasks without a slug" do
    problems = Importers::Integrity.problems(**expected_counts, blank_slugs: 3)

    assert_equal [ "3 tasks have no slug" ], problems
  end

  # The index importer skips rows without a bsg_id, so the expected item count
  # must be the count of identified rows, not the file length. The committed
  # source has no blank ids today, so the mechanism is pinned directly.
  test "source_size counts only the rows the block keeps" do
    path = Rails.root.join("tmp/integrity_source_size_test.json")
    File.write(path, JSON.generate([ { "bsg_id" => "a" }, { "bsg_id" => "" }, {} ]))

    assert_equal 3, Importers::Integrity.source_size(path)
    assert_equal 1, Importers::Integrity.source_size(path) { |row| row["bsg_id"].present? }
  ensure
    File.delete(path) if File.exist?(path)
  end
end
