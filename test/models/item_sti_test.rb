require "test_helper"

# Every Item STI subclass shares one contract: it is an Item, and it round
# trips through the database as its own type. Table-driven so the ten
# subclasses get identical assertions from one place instead of ten
# copy-pasted files.
class ItemStiTest < ActiveSupport::TestCase
  SUBCLASSES = [
    [ Item::Ammo,      "ammo",    "5.45x39 PS",    "PS" ],
    [ Item::Armor,     "armor",   "PACA",          "PACA" ],
    [ Item::Container, "cont",    "Scav Backpack", "Scav BP" ],
    [ Item::Generic,   "generic", "Generic Item",  "GI" ],
    [ Item::Key,       "key",     "Factory Key",   "FK" ],
    [ Item::Magazine,  "mag",     "30-round mag",  "30rnd" ],
    [ Item::Medical,   "med",     "AI-2",          "AI-2" ],
    [ Item::Provision, "prov",    "Emelya Rye",    "Emelya" ],
    [ Item::Throwable, "throw",   "RGD-5",         "RGD-5" ],
    [ Item::Weapon,    "weapon",  "AK-74M",        "AK-74M" ]
  ].freeze

  test "STI subclasses inherit from Item" do
    SUBCLASSES.each do |klass, _|
      assert_operator klass, :<, Item, "#{klass} is not an Item subclass"
    end
  end

  test "STI subclasses persist and reload with their own type" do
    SUBCLASSES.each do |klass, prefix, full_name, short_name|
      item = klass.create!(bsg_id: "#{prefix}-#{SecureRandom.hex(4)}", full_name: full_name, short_name: short_name)

      assert_equal klass.name, item.type
      assert_instance_of klass, Item.find(item.id)
    end
  end
end
