module ApplicationHelper
  # When the reference data last changed. A player checking a price or a quest
  # route wants to know whether they are reading this wipe's numbers, and the
  # import runs from tarkov.dev rather than by hand.
  #
  # Cached: two MAX() scans over the item and task tables, which only change on
  # import.
  def data_freshness
    Rails.cache.fetch("data/freshness", expires_in: 1.hour) do
      [ Item.maximum(:updated_at), Task.maximum(:updated_at) ].compact.max
    end
  end
end
