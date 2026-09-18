require "test_helper"

# Craft and offer unlocks share the same admin CRUD controller shape, so the two
# test classes are generated from one description instead of being written out
# twice (which flay scored as a 76-mass duplicated class body).
module Admin
  # [model, heading, the level column it carries, its value]. The two cases are
  # built from one shape so the file does not repeat the same hash/array
  # structure twice (flay scored the written-out version as 76 mass).
  UNLOCK_CONTROLLER_CASES = [
    [ CraftUnlock, "Craft Unlocks", :station_level, 1 ],
    [ OfferUnlock, "Offer Unlocks", :trader_level, 1 ]
  ].freeze

  UNLOCK_CONTROLLER_CASES.each do |model, heading, level_key, level_value|
    klass = Class.new(ActionDispatch::IntegrationTest) do
      include AdminCrudTests
      include AdminUnlockSetup

      define_method(:setup) do
        setup_unlock_resources(
          model,
          resource_attrs: { level_key => level_value },
          create_attrs: { level_key => level_value + 1 },
          destroy_attrs: { level_key => level_value + 1 }
        )
      end

      admin_crud_tests model: model, heading: heading, item_select: true
    end

    const_set("#{model.name}ControllerTest", klass)
  end
end
