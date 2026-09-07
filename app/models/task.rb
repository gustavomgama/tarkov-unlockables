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
#
class Task < ApplicationRecord
  has_many :leads_tos, dependent: :destroy
  has_many :requirements, dependent: :destroy
  has_many :rewards, dependent: :destroy
  has_many :item_task_rewards, dependent: :destroy

  def prerequisite_chain(visited = [])
    return [] if visited.include?(id)
    visited << id

    chain = [ { name: name, full_name: full_name, given_by: given_by, level: requirements.first&.player_level } ]

    requirements.each do |req|
      req.previous_tasks.each do |pt|
        prev = Task.find_by(name: pt.task_name)
        chain += prev.prerequisite_chain(visited) if prev
      end
    end

    chain
  end
end
