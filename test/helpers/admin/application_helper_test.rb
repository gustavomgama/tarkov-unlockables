# frozen_string_literal: true

require "test_helper"

class Admin::ApplicationHelperTest < ActionView::TestCase
  include Admin::ApplicationHelper

  test "admin_resource_path resolves an STI subclass through its base class" do
    item = create_item("Admin Helper Item", klass: Item::Generic)

    assert_equal admin_item_path(item), admin_resource_path(item)
    assert_equal edit_admin_item_path(item), edit_admin_resource_path(item)
  ensure
    item&.destroy
  end

  test "admin_nav_link marks the active controller" do
    params[:controller] = "admin/items"

    html = admin_nav_link("Items", Item)

    assert_includes html, " bg-[var(--bg-surface)] text-[var(--accent)]\""
    assert_includes html, "href=\"/admin/items\""
  end

  test "admin_nav_link leaves an inactive controller unmarked" do
    params[:controller] = "admin/tasks"

    refute_includes admin_nav_link("Items", Item), " bg-[var(--bg-surface)] text-[var(--accent)]\""
  end
end
