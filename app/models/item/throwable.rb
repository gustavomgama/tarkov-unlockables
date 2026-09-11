# == Schema Information
#
# Table name: items
#
#  id          :bigint           not null, primary key
#  type        :string           default("Item::Generic"), not null
#  bsg_id      :string
#  slug        :string
#  full_name   :string
#  short_name  :string
#  wiki_title  :string
#  categories  :text             default([]), is an Array
#  links       :text             default([]), is an Array
#  images      :text             default([]), is an Array
#  data        :jsonb            not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  search_text :string           default(""), not null
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
class Item::Throwable < Item; end
