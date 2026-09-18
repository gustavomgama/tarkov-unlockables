# frozen_string_literal: true

# Provides loose text search that strips non-alphanumeric characters before
# matching, so "sr3m" matches "SR-3M", "sr 3m", etc.
module LooseSearchable
  extend ActiveSupport::Concern

  class_methods do
    # Columns covered by the trigram-indexed search_text column.
    SEARCH_TEXT_COVERED = {
      "Item" => %w[full_name short_name],
      "Task" => %w[full_name name]
    }.freeze

    # @param query [String] the search term
    # @param columns [Array<String>] column names to search (must be strings, not symbols)
    # @return [ActiveRecord::Relation]
    def loose_search(query, columns:)
      return all if query.blank?

      stripped_query = query.to_s.gsub(/[^a-zA-Z0-9]/, "")
      return all if stripped_query.blank?

      columns = Array(columns).map(&:to_s)

      # Fast path: stripped query hits the trigram GIN index on search_text
      # instead of regexp_replace() seq-scanning the table.
      covered = SEARCH_TEXT_COVERED[name]
      if covered && columns.sort == covered.sort && column_names.include?("search_text")
        return where("search_text LIKE ?", "%#{stripped_query.downcase}%")
      end

      like_value = "%#{stripped_query}%"
      conditions = columns.map do |column|
        unless column_names.include?(column)
          raise ArgumentError, "unknown search column: #{column.inspect}"
        end
        # Quoted identifier: the column is validated above, and quoting keeps
        # the SQL string safe even if a caller ever passes something dynamic.
        quoted = connection.quote_column_name(column)
        Arel.sql("regexp_replace(#{quoted}::text, '[^a-zA-Z0-9]', '', 'g') ILIKE ?")
      end

      where(conditions.join(" OR "), *Array.new(columns.size, like_value))
    end

    # Builds the indexed search blob from raw attribute values.
    def build_search_text(*values)
      values.join(" ").gsub(/[^a-zA-Z0-9]/, "").downcase
    end
  end
end
