class Admin::DashboardController < Admin::ApplicationController
  def index
    @stats = {
      items: Item.count,
      tasks: Task.count,
      properties: Property.count,
      slots: Slot.count,
      requirements: Requirement.count,
      rewards: Reward.count,
      leads_tos: LeadsTo.count,
      previous_tasks: PreviousTask.count,
      barter_unlocks: BarterUnlock.count,
      craft_unlocks: CraftUnlock.count,
      offer_unlocks: OfferUnlock.count
    }
  end
end
