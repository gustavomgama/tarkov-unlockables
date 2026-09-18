 # db/seeds.rb — orchestrator: items first (so bsg_id → id is resolvable),
 # then full task graph, then cross-table task_id resolution for item_task_rewards.

 puts "Importing items (index → tarkovdev → wiki)..."
 Importers::Index.import!
 Importers::TarkovDev.import!
 Importers::Wiki.import!

 puts "Importing task graph..."
 Importers::TaskGraph.import!

 puts "Backfilling calibers from gun/preset names..."
 Item.populate_calibers_from_names

 puts "Resolving item_task_rewards.task_id..."
 Importers::ItemTaskRewardResolver.call

 # A count mismatch means the importer dropped rows, not that the data is odd:
 # 52 blank-id quests once collapsed into one row and 51 quests disappeared
 # silently. Fail the seed instead of serving an incomplete site.
 integrity_problems = Importers::Integrity.problems
 abort "❌ Seed integrity: #{integrity_problems.join('; ')}" if integrity_problems.any?

 puts "Done. Items: #{Item.count}, Tasks: #{Task.count}, " \
     "LeadsTos: #{LeadsTo.count}, Requirements: #{Requirement.count}, " \
     "Rewards: #{Reward.count}, " \
     "LooseItems: #{LooseItem.count}, OfferUnlocks: #{OfferUnlock.count}, " \
     "BarterUnlocks: #{BarterUnlock.count}, CraftUnlocks: #{CraftUnlock.count}"
