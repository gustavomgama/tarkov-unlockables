# == Schema Information
#
# Table name: items
#
#  id         :bigint           not null, primary key
#  bsg_id     :string
#  slug       :string
#  full_name  :string
#  short_name :string
#  categories :text             default([]), is an Array
#  links      :text             default([]), is an Array
#  images     :text             default([]), is an Array
#
class Item < ApplicationRecord
  has_one :property, dependent: :destroy
  has_many :item_task_rewards, dependent: :destroy
  has_many :item_hideouts, dependent: :destroy
  has_many :item_barters, dependent: :destroy
  has_many :item_currencies, dependent: :destroy

  ObtainEntry = Struct.new(:type, :source, keyword_init: true)
  UnlockPath = Struct.new(:task, :reward_type, :unlock_method, keyword_init: true)

  def obtain_from
    entries = []

    item_task_rewards.find_each { |r| entries << ObtainEntry.new(type: :task_reward, source: r) }
    item_hideouts.find_each { |r| entries << ObtainEntry.new(type: :hideout, source: r) }
    item_barters.find_each { |r| entries << ObtainEntry.new(type: :barter, source: r) }
    item_currencies.find_each { |r| entries << ObtainEntry.new(type: :currency, source: r) }

    entries
  end

  def obtain_types
    obtain_from.map(&:type).uniq
  end

  def obtain_from_tasks
    obtain_from.select { |e| e.type == :task_reward }
  end

  def obtain_from_hideouts
    obtain_from.select { |e| e.type == :hideout }
  end

  def obtain_from_barters
    obtain_from.select { |e| e.type == :barter }
  end

  def obtain_from_currencies
    obtain_from.select { |e| e.type == :currency }
  end

  def requires_task?
    %w[OfferUnlock BarterUnlock CraftUnlock].any? do |model_name|
      model_name.constantize.exists?(item_id: bsg_id)
    end
  end

  scope :task_gated, -> {
    where(bsg_id: [OfferUnlock.pluck(:item_id), BarterUnlock.pluck(:item_id), CraftUnlock.pluck(:item_id)].flatten.uniq)
  }

  def self.search(query)
    return all if query.blank?

    q = "%#{query}%"
    where("slug ILIKE ? OR full_name ILIKE ? OR short_name ILIKE ?", q, q, q)
  end

  def how_to_unlock
    paths = []

    item_task_rewards.find_each do |itr|
      task = Task.find_by(bsg_id: itr.task_id)
      next unless task
      paths << UnlockPath.new(
        task: task,
        reward_type: itr.reward_type,
        unlock_method: :task_reward
      )
    end

    Reward.joins(:offer_unlocks).where(offer_unlocks: {item_id: bsg_id}).find_each do |reward|
      paths << UnlockPath.new(
        task: reward.task,
        reward_type: reward.reward_type,
        unlock_method: :offer_unlock
      )
    end

    Reward.joins(:barter_unlocks).where(barter_unlocks: {item_id: bsg_id}).find_each do |reward|
      paths << UnlockPath.new(
        task: reward.task,
        reward_type: reward.reward_type,
        unlock_method: :barter_unlock
      )
    end

    Reward.joins(:craft_unlocks).where(craft_unlocks: {item_id: bsg_id}).find_each do |reward|
      paths << UnlockPath.new(
        task: reward.task,
        reward_type: reward.reward_type,
        unlock_method: :craft_unlock
      )
    end

    Reward.joins(:loose_items).where(loose_items: {item_id: bsg_id}).find_each do |reward|
      paths << UnlockPath.new(
        task: reward.task,
        reward_type: reward.reward_type,
        unlock_method: :loose_item
      )
    end

    paths.uniq
  end
end
