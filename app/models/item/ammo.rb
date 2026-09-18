# == Schema Information
#
# Table name: items
#
#  id                        :bigint           not null, primary key
#  type                      :string           default("Item::Generic"), not null
#  bsg_id                    :string
#  slug                      :string
#  full_name                 :string
#  short_name                :string
#  wiki_title                :string
#  categories                :text             default([]), is an Array
#  links                     :text             default([]), is an Array
#  images                    :text             default([]), is an Array
#  data                      :jsonb            not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  search_text               :string           default(""), not null
#  armor_class_effectiveness :jsonb            not null
#
# Indexes
#
#  index_items_on_bsg_id            (bsg_id) UNIQUE
#  index_items_on_categories        (categories) USING gin
#  index_items_on_data              (data) USING gin
#  index_items_on_full_name         (full_name)
#  index_items_on_search_text_trgm  (search_text) USING gin
#  index_items_on_slug              (slug)
#  index_items_on_type              (type)
#
class Item::Ammo < Item
  # The wiki's ballistics chart rates a round 0-6 against each armor class.
  # Level 4 is "Effective" (3 to 5 rounds stopped on average), which is where
  # the chart considers the round to penetrate that class.
  EFFECTIVE_LEVEL = 4

  # `armor_class_effectiveness` is the wiki's row for this round: {"1"=>5,
  # "2"=>0, …}; empty when the chart has no row (14 rounds in this snapshot).
  def wiki_effectiveness?
    armor_class_effectiveness.present?
  end

  # The wiki levels in armor-class order, or nil without a chart row.
  def armor_class_levels
    return nil unless wiki_effectiveness?

    (1..6).map { |armor_class| armor_class_effectiveness[armor_class.to_s].to_i }
  end

  def defeats_armor_class?(armor_class)
    armor_class_effectiveness[armor_class.to_s].to_i >= EFFECTIVE_LEVEL
  end

  # Every armor class the round penetrates. The chart is monotonic — a round
  # that defeats class 5 always defeats class 4 — which is what lets the view
  # state a range.
  def defeated_armor_classes
    (1..6).select { |armor_class| defeats_armor_class?(armor_class) }
  end

  # Heaviest armor class the round defeats: the wiki chart's rule where it has
  # a row, the penetration/10 approximation where it does not.
  def defeats_class
    return Item.penetration_class(penetration) unless wiki_effectiveness?

    defeated_armor_classes.max || 0
  end

  # Penetration power, under either of the two spellings the sources use.
  def penetration
    data["penetration_power"].presence || data["penetration"]
  end
end
