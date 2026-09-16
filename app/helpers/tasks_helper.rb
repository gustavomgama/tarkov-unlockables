module TasksHelper
  # Reward rows grouped by what the player actually receives, in the order a
  # player checks them. Groups with nothing in them are dropped so the
  # rewards panel never renders an empty section.
  REWARD_GROUPS = [
    [ "Items", "badge-currency" ],
    [ "Trader offer", "badge-offer" ],
    [ "Barter", "badge-barter" ],
    [ "Craft", "badge-craft" ]
  ].freeze

  REWARD_ASSOCIATIONS = {
    "Items" => :loose_items,
    "Trader offer" => :offer_unlocks,
    "Barter" => :barter_unlocks,
    "Craft" => :craft_unlocks
  }.freeze

  def reward_groups(reward)
    REWARD_GROUPS.filter_map do |label, badge|
      rows = reward.public_send(REWARD_ASSOCIATIONS[label])
      [ label, rows, badge ] if rows.any?
    end
  end

  def reward_count(task)
    task.rewards.sum { |reward| reward_groups(reward).sum { |_, rows, _| rows.size } }
  end

  # Money rewards arrive in the same list as items; name them for what they
  # are so "Items" does not read as a bug next to "Roubles".
  def reward_label(label, row)
    return label unless label == "Items"
    row.item_name.to_s.match?(/roubles|dollars|euros|₽|\$/i) ? "Currency" : label
  end
end
