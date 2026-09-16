module ItemsHelper
  # Categories that carry no information for a reader (BSG-internal flags).
  NOISE_CATEGORIES = %w[not_functional].freeze

  # Raw BSG category keys whose default Title Case is either wrong or
  # meaningless to a player. Anything not listed falls back to #humanize.
  CATEGORY_LABELS = {
    "noFlea" => "Not on flea market",
    "specialSlot" => "Special slot",
    "not_functional" => "Not functional",
    "armorplate" => "Armor plate (soft)",
    "armor_plate" => "Armor plate (hard)",
    "rig" => "Chest rig",
    "chest_rig" => "Chest rig (armored)",
    "meds" => "Medical supplies",
    "pistolgrip" => "Pistol grip",
    "flashhiders_brakes" => "Flash hiders & brakes",
    "receivers_slides" => "Receivers & slides",
    "stocks_chassis" => "Stocks & chassis",
    "smg" => "SMG"
  }.freeze

  # Player-facing name for a raw category key.
  def category_label(raw)
    CATEGORY_LABELS.fetch(raw.to_s) { raw.to_s.humanize }
  end

  # How an applied filter reads back to the user. Without this the pills echo
  # raw keys ("Caliber: Caliber556x45NATO", "Category: noFlea").
  #
  # A case rather than a hash of lambdas: a lambda in a module body captures
  # the module as self, so calling a helper from inside it raises.
  def filter_value_label(type, value)
    case type.to_s
    when "armor_class" then "Class #{value}"
    when "category" then category_label(value)
    when "caliber" then Item.caliber_display(value)
    when "exclude_ref" then "Ref items"
    else value.to_s.humanize
    end
  end

  # Links whose bare host is more useful read as a source name.
  LINK_LABELS = {
    "escapefromtarkov.fandom.com" => "Wiki",
    "tarkov.dev" => "tarkov.dev",
    "tarkov-market.com" => "Market"
  }.freeze

  def caliber_display(raw)
    Item.caliber_display(raw)
  end

  # Caliber values arrive in three shapes:
  #   "Caliber556x45NATO"            (weapons, ammo)
  #   "[[5.56x45mm NATO]], [[.300]]" (magazines, from the wiki)
  #   nil
  # Returns a display string, or nil when there is nothing readable.
  def caliber_label(raw)
    values = Array(raw).flat_map { |v| v.to_s.split(",") }
                       .map { |v| v.delete("[]").strip }
                       .reject(&:blank?)
                       .uniq
    return nil if values.empty?

    values.map { |v| caliber_display(v) }.join(" / ")
  end

  def item_caliber(item)
    caliber_label(item.data["caliber"]) || Item.parse_caliber_from_name(item.full_name)
  end

  # Armor class → the shared lethality ramp (--ac1 … --ac6).
  def armor_class_tone(value)
    n = value.to_i.clamp(1, 6)
    "var(--ac#{n})"
  end

  # Penetration power → the heaviest armor class it beats reliably.
  # Community approximation: roughly 10 penetration per armor class, rounded
  # down so the label states the reliable case, not the lucky one.
  # ponytail: single constant, retune here when the wipe changes it.
  def penetration_class(value)
    (value.to_f / 10).floor.clamp(0, 6)
  end

  def penetration_tone(value)
    n = penetration_class(value)
    n.zero? ? "var(--ac1)" : "var(--ac#{n})"
  end

  # Armor class value (1–6) as a filled bar scale.
  def armor_scale(value)
    Array.new(6) { |i| (i + 1) <= value.to_i.clamp(0, 6) }
  end

  def penetration_scale(value)
    n = penetration_class(value)
    Array.new(6) { |i| (i + 1) <= n }
  end

  # Categories worth showing: drops BSG-internal flags and caliber
  # categories, because the caliber is already in the item name.
  def category_labels(item, limit: nil)
    labels = item.categories.reject do |c|
      NOISE_CATEGORIES.include?(c) || c.sub(/_(pack|box|bundle)\z/, "").match?(/\A\d|\A\./)
    end
    labels = labels.first(limit) if limit
    labels.map { |c| category_label(c) }
  end

  # One query for every bsg_id lookup on the page, negative results cached so
  # a page full of unresolvable ids still fires a single query.
  def bsg_items(ids)
    ids = Array(ids).compact.uniq
    cache = (@bsg_item_cache ||= {})
    missing = ids - cache.keys
    if missing.any?
      Item.where(bsg_id: missing).find_each { |i| cache[i.bsg_id] = i }
      missing.each { |id| cache[id] ||= nil }
    end
    ids.filter_map { |id| cache[id] }
  end

  def bsg_item(id)
    bsg_items([ id ]).first
  end

  # Wiki infobox text ("effect") arrives as markup: <br/>, '''bold''' and
  # [[File:icon.png|46px|Light bleeding]] embeds. Rendering it raw shows the
  # markup instead of the fact, so reduce it to the readable labels and keep
  # the original line structure. Display-only: the stored value is untouched.
  def clean_wiki_text(text)
    return nil if text.blank?

    cleaned = text.to_s.dup
    cleaned = cleaned.gsub("]][[", "]], [[")
    cleaned = cleaned.gsub(/\[\[File:[^|\]]*\|[^|\]]*\|([^\]]*)\]\]/, '\1')
    cleaned = cleaned.gsub(/\[\[File:[^|\]]*(?:\|[^\]]*)?\]\]/, " ")
    cleaned = cleaned.gsub(/\[\[[^|\]]*\|([^\]]*)\]\]/, '\1')
    cleaned = cleaned.gsub(/\[\[([^\]]*)\]\]/, '\1')
    cleaned = cleaned.gsub(/\[https?:\/\/\S+\s+([^\]]*)\]/, '\1')
    cleaned = cleaned.delete("'")
    cleaned = cleaned.gsub(/<br\s*\/?>/i, "\n")
    cleaned = cleaned.gsub(/<[^>]+>/, " ")
    cleaned = cleaned.gsub(/[ \t]+/, " ")
    cleaned = cleaned.gsub(/ ?\n ?/, "\n")
    cleaned = cleaned.gsub(/\n{2,}/, "\n")
    # "Removes:Light bleeding" — the embed swallowed the space.
    cleaned = cleaned.gsub(/:(?=[A-Za-z])/, ": ")
    cleaned.strip.presence
  end

  # In development Rails wraps partial output in <!-- BEGIN … --> markers, so
  # an empty partial still carries text. Strip comments before asking whether
  # a partial produced anything to show.
  def rendered_content?(html)
    html.to_s.gsub(/<!--.*?-->/m, "").strip.present?
  end

  # Long text ("Fragmentation Grenade") at display size reads as a headline;
  # keep --xl for short numbers and tokens only.
  def stat_scale(value, limit: 14)
    value.to_s.length <= limit ? "stat--xl" : ""
  end

  # Some imported task names are still slugs ("create-a-distraction-part-1").
  # Showing the readable form is presentation, not a data change.
  def task_display_name(name)
    text = name.to_s
    text.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)+\z/) ? text.tr("-", " ").titleize : text
  end

  def external_link_label(url)
    host = URI.parse(url.to_s).host
    LINK_LABELS[host] || host || url
  rescue URI::InvalidURIError
    url
  end

  def format_number(value)    number = value.to_s.tr(",", "").strip
    return value if number.match?(/\A\d+\z/)

    number_with_delimiter(number.to_i)
  end

  # Compact per-card readout: the one or two numbers a browser scans for.
  # Reads only columns the index already loaded, so a card costs no extra
  # query. Returns [[label, value, tone], …].
  def card_stats(item)
    d = item.data || {}
    pairs = []
    case item
    when Item::Ammo
      pen = d["penetration_power"].presence || d["penetration"].presence
      pairs << [ "DMG", d["damage"], nil ] if d["damage"].present?
      pairs << [ "PEN", pen, penetration_tone(pen) ] if pen.present?
    when Item::Armor
      pairs << [ "CLASS", d["class"], armor_class_tone(d["class"]) ] if d["class"].present?
    when Item::Weapon
      caliber = caliber_label(d["caliber"]) || Item.parse_caliber_from_name(item.full_name)
      pairs << [ "CAL", caliber, nil ] if caliber
    when Item::Magazine
      capacity = magazine_capacity(item)
      caliber = caliber_label(d["caliber"]) || Item.parse_caliber_from_name(item.full_name)
      pairs << [ "RNDS", capacity, nil ] if capacity
      pairs << [ "CAL", caliber, nil ] if caliber
    when Item::Generic
      pairs << [ "PART", d["type"], nil ] if d["type"].present?
    end
    pairs
  end

  # Two chips is the useful maximum: the specific category and the broad one.
  # Drops the broad one when it is just a prefix of the specific one
  # ("Armor" vs "Armor vests", "Ammobox" vs "Ammo boxes").
  def category_chips(item)
    labels = category_labels(item)
    return labels if labels.size <= 2

    shorten = ->(s) { s.downcase.delete(" ") }
    picks = [ labels.first, labels.last ].uniq
    picks.reject { |l| picks.any? { |other| other != l && shorten[other].include?(shorten[l]) } }
  end

  # Rounds a weapon or magazine accepts, hardest-hitting first. Shares the
  # request-level bsg_id cache, so a page resolves default ammo, presets and
  # the accepted-ammo list in one query.
  def compatible_ammo(item)
    ids = Array(item.data["allowed_ammo"]).presence || Array(item.data["allowedAmmo"])
    bsg_items(ids)
      .select { |i| i.is_a?(Item::Ammo) }
      .sort_by { |a| -a.data["penetration_power"].to_i }
  end

  # Magazines carry no capacity field; the round count only ever appears in
  # the name ("... 30-round magazine"). Reading it from there is still the
  # data, just a different column.
  def magazine_capacity(item)
    item.full_name.to_s[/\b(\d+)[-\s]round/i, 1]
  end
end
