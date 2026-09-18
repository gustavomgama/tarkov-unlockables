# frozen_string_literal: true

module Importers
  # Compares what the seed actually imported against what its sources contain.
  #
  # The failure this guards against is silent row loss: 52 Ref/Arena quests have
  # no bsg_id in the source, and keying the upsert on it collapsed them into a
  # single row — 51 quests vanished with no error and no failing test. A count
  # mismatch is a bug in the importer, not a data problem, so the seed aborts.
  #
  # The counts are read from the committed sources, so a data refresh is checked
  # against the files it just imported rather than against a hardcoded number.
  module Integrity
    def self.problems(task_count: Task.count, item_count: Item.count, blank_slugs: Task.where(name: [ nil, "" ]).count)
      expected_tasks = source_size(TaskGraph::SOURCE)
      expected_items = source_size(Index::SOURCE) { |row| row["bsg_id"].present? }

      problems = []
      problems << "imported #{task_count} tasks, the source has #{expected_tasks}" if task_count != expected_tasks
      problems << "imported #{item_count} items, the source has #{expected_items}" if item_count != expected_items
      problems << "#{blank_slugs} tasks have no slug" if blank_slugs.positive?
      problems
    end

    # The index source is a JSON array, the task source too; both are counted the
    # way their importer consumes them.
    def self.source_size(path)
      rows = JSON.parse(File.read(path))
      rows = rows.select { |row| yield(row) } if block_given?
      rows.size
    end
  end
end
