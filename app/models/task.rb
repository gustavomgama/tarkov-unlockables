# == Schema Information
#
# Table name: tasks
#
#  id                   :bigint           not null, primary key
#  bsg_id               :string
#  full_name            :string
#  name                 :string
#  wiki_link            :string
#  given_by             :string
#  kappa_required       :boolean
#  lightkeeper_required :boolean
#  leads_tos_count      :integer          default(0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  search_text          :string           default(""), not null
#  map_id               :string
#  map_name             :string
#  experience           :integer
#  faction              :string
#  needed_keys          :jsonb            not null
#
# Indexes
#
#  index_tasks_on_full_name         (full_name)
#  index_tasks_on_given_by          (given_by)
#  index_tasks_on_map_name          (map_name)
#  index_tasks_on_name              (name)
#  index_tasks_on_search_text_trgm  (search_text) USING gin
#
class Task < ApplicationRecord
  normalizes_links :wiki_link

  has_many :leads_tos, dependent: :destroy
  has_many :requirements, dependent: :destroy
  has_many :rewards, dependent: :destroy
  has_many :item_task_rewards, dependent: :destroy
  # Source order, which is how the game lists them.
  has_many :task_objectives, -> { order(:position) }, dependent: :destroy
  # Trader offers this quest makes purchasable (item_currencies.task_id).
  has_many :gated_currencies, -> { where(task_unlock: true) },
           class_name: "ItemCurrency", dependent: :nullify, inverse_of: :task

  # Pointers from other tasks: a task that leads to this one, or that requires it
  # as a prerequisite. Both columns are optional but their FK is restrict, so
  # without these the pointer row blocked the delete and the admin Delete action
  # 500d for any task in the middle of the graph. Nullify drops the dangling
  # reference and leaves the other task's own rows intact.
  has_many :incoming_leads_tos, class_name: "LeadsTo", foreign_key: :follow_up_task_id, dependent: :nullify
  has_many :referencing_previous_tasks, class_name: "PreviousTask", foreign_key: :task_id, dependent: :nullify

  # Keeps the trigram-indexed search_text column fresh for loose_search.
  before_validation :set_search_text

  def set_search_text
    self.search_text = "#{full_name} #{name}".gsub(/[^a-zA-Z0-9]/, "").downcase
  end

  def self.ransackable_associations(auth_object = nil)
    %w[item_task_rewards leads_tos requirements rewards]
  end

  # Walks the prerequisite graph without per-level queries: the caller
  # passes a preloaded name → task map (built once per request in the
  # controller as @task_map); nested calls share it. Called without a map
  # (console, tests) it builds one — 3 queries total instead of ~3 per level.
  def prerequisite_chain(visited = [], task_map = nil, alternative: false)
    task_map ||= Task.includes(requirements: :previous_tasks).index_by(&:name)
    return [] if visited.include?(id)
    visited << id

    # Read through the map's preloaded copy: the object this was called on
    # (e.g., an unlock's task) has no preloaded requirements, so touching
    # self.requirements would fire one query per chain node.
    node = task_map[name] || self
    requirements = node.requirements
    first_req = requirements.first
    chain = [ {
      id:                  id,
      name:                name,
      full_name:           full_name,
      given_by:            given_by,
      player_level:        first_req&.player_level.to_i,
      trader_requirements: first_req&.trader_level || [],
      # Set when the wiki lists this guess as one of several alternatives.
      alternative:         alternative
    } ]

    requirements.each do |req|
      req.previous_tasks.each do |pt|
        prev = task_map[pt.task_name]
        chain += prev.prerequisite_chain(visited, task_map, alternative: pt.alternative) if prev
      end
    end

    chain
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[full_name name given_by]
  end
end
