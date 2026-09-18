class AddUniqueIndexToTasksBsgId < ActiveRecord::Migration[8.1]
  # TaskGraph upserts by bsg_id (`find_or_initialize_by`) and resolves every
  # leads_to / reward / prerequisite reference with `Task.find_by(bsg_id: ...)`,
  # so that column is on the hot path of every import — with no index, each of
  # those is a sequential scan. `items.bsg_id` is already uniquely indexed and
  # `tasks.bsg_id` was not; the column holds no blanks and no duplicates, so the
  # unique index builds as-is and pins the invariant the importer assumes.
  #
  # Concurrently: the unique index is added without holding a write lock on
  # `tasks` (`add_index` otherwise takes an exclusive lock for the build).
  disable_ddl_transaction!

  # `if_not_exists` so a database that already built the index (under this
  # migration's earlier timestamp) converges instead of aborting.
  def change
    add_index :tasks, :bsg_id, unique: true, algorithm: :concurrently, if_not_exists: true
  end
end
