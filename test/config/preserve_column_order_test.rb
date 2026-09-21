# frozen_string_literal: true

require "test_helper"

# The initializer overrides Rails' SchemaDumper so db/schema.rb keeps the
# migration's physical column order instead of the alphabetical default. The
# override has no isolated seam, so the committed schema is what this checks:
# it is the observable output of the override, and it goes wrong the moment
# someone removes it.
class PreserveColumnOrderTest < ActiveSupport::TestCase
  test "db/schema.rb keeps the physical column order of a non-alphabetical table" do
    physical = ActiveRecord::Base.connection.columns("tasks").map(&:name) - [ "id" ]

    assert_equal physical, schema_columns("tasks")
  end

  # Without this the test above would still pass on an alphabetically ordered
  # table, which proves nothing about the override.
  test "the tasks table is not stored alphabetically" do
    physical = ActiveRecord::Base.connection.columns("tasks").map(&:name) - [ "id" ]

    refute_equal physical.sort, physical
  end

  private

  def schema_columns(table)
    section = File.read(Rails.root.join("db/schema.rb"))[/create_table "#{table}".*?\n  end\n/m]

    assert_not_nil section, "db/schema.rb has no create_table for #{table}"
    section.scan(/t\.\w+ "([^"]+)"/).flatten
  end
end
