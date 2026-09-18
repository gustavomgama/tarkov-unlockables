# frozen_string_literal: true

# The datastore (`datastore/canonical/`) is the source of truth: it replaces
# every row rather than merging with the offlinedata-derived importers.
puts "Importing the datastore (datastore/canonical/)..."
Importers::Datastore.import!

# Canonical normally carries the task id directly; this is the fallback for the
# rows whose source task id was blank.
puts "Resolving item_task_rewards.task_id..."
Importers::ItemTaskRewardResolver.call

puts "Done. Items: #{Item.count}, Tasks: #{Task.count}, " \
     "LeadsTos: #{LeadsTo.count}, Requirements: #{Requirement.count}, " \
     "Rewards: #{Reward.count}, " \
     "LooseItems: #{LooseItem.count}, OfferUnlocks: #{OfferUnlock.count}, " \
     "BarterUnlocks: #{BarterUnlock.count}, CraftUnlocks: #{CraftUnlock.count}"
