# frozen_string_literal: true

# Provides loose text search that strips non-alphanumeric characters before
# matching, so "sr3m" matches "SR-3M", "sr 3m", etc.
module LooseSearchable
  extend ActiveSupport::Concern

  class_methods do
    # @param query [String] the search term
    # @param columns [Array<String>] column names to search (must be strings, not symbols)
    # @return [ActiveRecord::Relation]
    def loose_search(query, columns:)
      return all if query.blank?

      stripped_query = query.to_s.gsub(/[^a-zA-Z0-9]/, "")
      return all if stripped_query.blank?

      like_value = "%#{stripped_query}%"
      conditions = columns.map do |col|
        # brakeman:ignore SQL
        # col is a hardcoded column name from caller (e.g., "full_name"); never user input
        Arel.sql("regexp_replace(#{col}::text, '[^a-zA-Z0-9]', '', 'g') ILIKE ?")
      end

      where(conditions.join(" OR "), *Array.new(columns.size, like_value))
    end
  end
end
