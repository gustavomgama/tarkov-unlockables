class KeysController < ApplicationController
  # Every key a quest asks for, grouped by the key item. Small (70 keys over
  # 57 tasks), so load the tasks once and fold in Ruby.
  def index
    by_key = {}
    # Rails drops an empty-array condition, so ask jsonb for the length.
    Task.where("jsonb_array_length(needed_keys) > 0").find_each do |task|
      Array(task.needed_keys).each do |key|
        entry = (by_key[[ key["item_id"], key["item_name"] ]] ||= {
          item_id: key["item_id"], name: key["item_name"], maps: [], tasks: []
        })
        entry[:maps] << key["map_name"] if key["map_name"].present?
        entry[:tasks] << task unless entry[:tasks].include?(task)
      end
    end
    @keys = by_key.values.sort_by { |key| key[:name].to_s }
    @map_count = @keys.flat_map { |key| key[:maps] }.uniq.size
    fresh_when(etag: [ Task.maximum(:updated_at), @keys.size ], public: true)
  end
end
