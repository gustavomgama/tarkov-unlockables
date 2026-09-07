# db/seeds.rb — orchestrator: items first (so bsg_id → id is resolvable),
# then full task graph, then cross-table task_id resolution for item_task_rewards.

puts "Importing items (index → tarkovdev → wiki)..."
Importers::Index.import!
Importers::TarkovDev.import!
Importers::Wiki.import!

puts "Importing task graph..."
Importers::TaskGraph.import!

puts "Resolving item_task_rewards.task_id..."
ItemTaskReward.where(task_id: nil).find_each do |itr|
  task = Task.find_by(full_name: itr.task_name) || Task.find_by(name: itr.task_name)
  itr.update!(task_id: task.id) if task
end

puts "Done. Items: #{Item.count}, Tasks: #{Task.count}, " \
     "LeadsTos: #{LeadsTo.count}, Requirements: #{Requirement.count}, " \
     "Rewards: #{Reward.count}, " \
     "LooseItems: #{LooseItem.count}, OfferUnlocks: #{OfferUnlock.count}, " \
     "BarterUnlocks: #{BarterUnlock.count}, CraftUnlocks: #{CraftUnlock.count}"
