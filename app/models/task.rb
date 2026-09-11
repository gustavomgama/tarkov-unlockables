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
#
# Indexes
#
#  index_tasks_on_full_name         (full_name)
#  index_tasks_on_given_by          (given_by)
#  index_tasks_on_name              (name)
#  index_tasks_on_search_text_trgm  (search_text) USING gin
#
class Task < ApplicationRecord
  normalizes_links :wiki_link

  has_many :leads_tos, dependent: :destroy
  has_many :requirements, dependent: :destroy
  has_many :rewards, dependent: :destroy
  has_many :item_task_rewards, dependent: :destroy

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
  def prerequisite_chain(visited = [], task_map = nil)
    task_map ||= Task.includes(requirements: :previous_tasks).index_by(&:name)
    return [] if visited.include?(id)
    visited << id

    first_req = requirements.first
    chain = [ {
      id:                  id,
      name:                name,
      full_name:           full_name,
      given_by:            given_by,
      player_level:        first_req&.player_level.to_i,
      trader_requirements: first_req&.trader_level || []
    } ]

    requirements.each do |req|
      req.previous_tasks.each do |pt|
        prev = task_map[pt.task_name]
        chain += prev.prerequisite_chain(visited, task_map) if prev
      end
    end

    chain
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[full_name name given_by]
  end
end
