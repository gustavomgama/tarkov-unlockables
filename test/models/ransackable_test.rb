require "test_helper"

# Admin search builds its queries from these allowlists. If one is missing,
# Ransack raises at request time instead of boot, so assert they all exist.
class RansackableTest < ActiveSupport::TestCase
  SEARCHABLE_MODELS = [
    Item, Task, Reward, Requirement, LeadsTo, PreviousTask,
    OfferUnlock, BarterUnlock, CraftUnlock
  ].freeze

  test "every searchable admin model declares ransackable attributes and associations" do
    SEARCHABLE_MODELS.each do |model|
      assert_kind_of Array, model.ransackable_attributes, "#{model} ransackable_attributes"
      assert_kind_of Array, model.ransackable_associations, "#{model} ransackable_associations"
    end
  end
end
