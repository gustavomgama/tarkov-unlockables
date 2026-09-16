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

  # Reward kinds that live in `rewards.data` instead of a table, with the
  # badge they render under.
  REWARD_DATA_KINDS = {
    "trader_standing" => [ "Standing", "badge-offer" ],
    "skill_level_reward" => [ "Skill", "badge-currency" ],
    "trader_unlock" => [ "Trader unlock", "badge-offer" ],
    "trader_dialogue_unlock" => [ "Dialogue", "badge-offer" ],
    "achievement" => [ "Achievement", "badge-task" ],
    "customization" => [ "Customization", "badge-hideout" ]
  }.freeze

  def reward_data_groups(reward)
    data = reward.data.is_a?(Hash) ? reward.data : {}
    REWARD_DATA_KINDS.filter_map do |kind, (label, badge)|
      rows = Array(data[kind])
      next if rows.empty?
      [ label, badge, rows.map { |row| reward_data_line(kind, row) } ]
    end
  end

  def reward_data_line(kind, row)
    case kind
    when "trader_standing"
      "#{row['trader_slug'].to_s.titleize} #{format('%+g', row['standing'].to_f)} rep"
    when "skill_level_reward"
      "#{row['skill']} level #{row['level']}"
    when "trader_unlock", "trader_dialogue_unlock"
      row["trader_name"].presence || row["trader_slug"].to_s.titleize
    when "achievement"
      row["name"]
    when "customization"
      row["customizationType"].to_s.titleize
    else
      row.values.compact.join(" ")
    end
  end

  def reward_count(task)
    task.rewards.sum do |reward|
      reward_groups(reward).sum { |_, rows, _| rows.size } +
        reward_data_groups(reward).sum { |_, _, lines| lines.size }
    end
  end

  # Trader level a requirement asks for, as [[name, level], …]. One formatter
  # for both the requirements panel and the timeline nodes.
  def trader_requirements(requirement)
    Array(requirement.trader_level).select { |tr| tr.is_a?(Hash) }
  end

  def trader_requirement_label(entry)
    name = entry["trader_name"].to_s.strip
    level = entry["trader_level"]
    name.empty? ? "LL#{level}" : "#{name.titleize} LL#{level}"
  end

  # Money rewards arrive in the same list as items; name them for what they
  # are so "Items" does not read as a bug next to "Roubles".
  def reward_label(label, row)
    return label unless label == "Items"
    row.item_name.to_s.match?(/roubles|dollars|euros|₽|\$/i) ? "Currency" : label
  end

  # Short badge per objective type. Falls back to the type, so a new
  # tarkov.dev objective kind shows up instead of vanishing.
  OBJECTIVE_LABELS = {
    "giveItem" => "Hand over",
    "giveQuestItem" => "Hand over",
    "findItem" => "Find",
    "findQuestItem" => "Find",
    "plantItem" => "Plant",
    "plantQuestItem" => "Plant",
    "visit" => "Visit",
    "mark" => "Mark",
    "shoot" => "Eliminate",
    "extract" => "Extract",
    "buildWeapon" => "Build",
    "traderLevel" => "Trader"
  }.freeze

  def objective_label(type)
    OBJECTIVE_LABELS[type.to_s] || type.to_s.titleize
  end
end
