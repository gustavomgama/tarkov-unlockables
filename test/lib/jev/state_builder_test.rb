# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class Jev::StateBuilderTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir("jev-state")
  end

  teardown do
    FileUtils.remove_entry(@root)
  end

  def write(path, content)
    full = File.join(@root, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
    full
  end

  def build(path)
    Jev::StateBuilder.new(root: @root).call(path)
  end

  test "carries the source, its mirrored test, and the files it includes" do
    write "app/models/item.rb", "class Item\n  include Searchable\nend\n"
    write "app/models/concerns/searchable.rb", "module Searchable\nend\n"
    write "test/models/item_test.rb", "class ItemTest\nend\n"

    state = build("app/models/item.rb")

    assert_equal Jev::PROJECT, state[:project]
    assert_equal "app/models/item.rb", state[:path]
    assert_includes state[:content], "class Item"
    assert_equal [ "test/models/item_test.rb" ], state[:tests].keys
    assert_equal [ "app/models/concerns/searchable.rb" ], state[:dependencies].keys
    assert_includes state[:dependencies]["app/models/concerns/searchable.rb"], "module Searchable"
  end

  test "finds a test by basename when the mirror path does not exist" do
    write "app/services/importers/datastore.rb", "class Datastore\nend\n"
    write "test/integration/datastore_test.rb", "class DatastoreTest\nend\n"

    assert_equal [ "test/integration/datastore_test.rb" ], build("app/services/importers/datastore.rb")[:tests].keys
  end

  test "finds a test that names the class when neither path nor basename matches" do
    # A made-up constant, so this fixture cannot itself be found as a test for
    # a real class by the content scan.
    write "app/services/importers/widget_resolver.rb", "class WidgetResolver\nend\n"
    write "test/services/seeds_test.rb", "class SeedsTest\n  Importers::WidgetResolver.call\nend\n"

    assert_equal [ "test/services/seeds_test.rb" ],
                 build("app/services/importers/widget_resolver.rb")[:tests].keys
  end

  test "a double-extension component resolves to its constant, not its mime type" do
    # A made-up constant, so this fixture cannot itself be found as a test for
    # a real component by the content scan.
    write "app/components/widgets/widget_component.html.erb", "<p>hi</p>\n"
    write "test/components/widgets_test.rb",
          "class WidgetsTest\n  Widgets::WidgetComponent.new\nend\n"

    assert_equal [ "test/components/widgets_test.rb" ],
                 build("app/components/widgets/widget_component.html.erb")[:tests].keys
  end

  test "finds a nested source file's test by its joined path name" do
    write "app/models/item/ammo.rb", "class Item::Ammo\nend\n"
    write "test/models/item_ammo_test.rb", "class ItemAmmoTest\nend\n"

    assert_equal [ "test/models/item_ammo_test.rb" ],
                 build("app/models/item/ammo.rb")[:tests].keys
  end

  test "a view is paired with the controller test that renders it" do
    write "app/views/items/show.html.erb", "<p>hi</p>\n"
    write "test/controllers/items_controller_test.rb", "class ItemsControllerTest\nend\n"

    assert_equal [ "test/controllers/items_controller_test.rb" ],
                 build("app/views/items/show.html.erb")[:tests].keys
  end

  test "a namespaced view maps to its namespaced controller test" do
    write "app/views/admin/items/_form.html.erb", "<p>hi</p>\n"
    write "test/controllers/admin/items_controller_test.rb", "class Admin::ItemsControllerTest\nend\n"

    assert_equal [ "test/controllers/admin/items_controller_test.rb" ],
                 build("app/views/admin/items/_form.html.erb")[:tests].keys
  end

  test "a view with no controller test is not claimed by an unrelated one" do
    write "app/views/layouts/application.html.erb", "<p>hi</p>\n"
    write "test/controllers/items_controller_test.rb", "class ItemsControllerTest\nend\n"

    assert_empty build("app/views/layouts/application.html.erb")[:tests]
  end

  test "a view directly under app/views has no controller to map to" do
    write "app/views/index.html.erb", "<p>hi</p>\n"
    write "test/controllers/items_controller_test.rb", "class ItemsControllerTest\nend\n"

    assert_empty build("app/views/index.html.erb")[:tests]
  end

  test "a short partial name does not match every test that mentions the word" do
    write "app/views/shared/_table.html.erb", "<p>hi</p>\n"
    write "test/models/item_test.rb", "class ItemTest\n  # Table of contents\nend\n"

    assert_empty build("app/views/shared/_table.html.erb")[:tests]
  end

  test "a same-suffix namespaced class does not claim a top-level test" do
    write "app/services/importers/namespaced_widget.rb", "class NamespacedWidget\nend\n"
    # Neither test's basename matches, so the content scan is what decides.
    write "test/services/admin/other_namespaced_widget_test.rb",
          "class Admin::NamespacedWidgetTest\nend\n"
    write "test/services/namespaced_widget_use_test.rb", "NamespacedWidget.call\n"

    assert_equal [ "test/services/namespaced_widget_use_test.rb" ],
                 build("app/services/importers/namespaced_widget.rb")[:tests].keys
  end

  test "a mirrored test is not widened by the content scan" do
    write "app/controllers/items_controller.rb", "class ItemsController\nend\n"
    write "test/controllers/items_controller_test.rb", "class ItemsControllerTest\nend\n"
    write "test/integration/other_test.rb", "ItemsController\n"

    assert_equal [ "test/controllers/items_controller_test.rb" ],
                 build("app/controllers/items_controller.rb")[:tests].keys
  end

  test "an extend of a lib module resolves to the lib file" do
    write "lib/thing.rb", "module Thing\nend\n"
    write "lib/consumer.rb", "class Consumer\n  extend Thing\nend\n"

    assert_equal [ "lib/thing.rb" ], build("lib/consumer.rb")[:dependencies].keys
  end

  test "reports no tests or dependencies when none exist" do
    write "lib/thing.rb", "class Thing\nend\n"

    state = build("lib/thing.rb")

    assert_empty state[:tests]
    assert_empty state[:dependencies]
  end

  test "a config file picks up the initializer that guards its ENV key" do
    write "config/environments/development.rb", "ENV[\"ADMIN_PASSWORD\"] ||= \"admin\"\n"
    write "config/initializers/admin_password_check.rb", "abort unless ENV[\"ADMIN_PASSWORD\"]\n"

    assert_equal [ "config/initializers/admin_password_check.rb" ],
                 build("config/environments/development.rb")[:dependencies].keys
  end

  test "a config file with no ENV keys has no guard dependencies" do
    write "config/puma.rb", "workers 1\n"
    write "config/initializers/other.rb", "ENV[\"SOMETHING\"]\n"

    assert_empty build("config/puma.rb")[:dependencies]
  end

  test "an initializer that does not share the ENV key is not included" do
    write "config/environments/production.rb", "ENV[\"SECRET_KEY_BASE\"]\n"
    write "config/initializers/other.rb", "ENV[\"OTHER_KEY\"]\n"

    assert_empty build("config/environments/production.rb")[:dependencies]
  end

  test "a missing file yields empty content rather than raising" do
    assert_equal "", build("app/missing.rb")[:content]
  end

  test "truncates content larger than the cap" do
    write "app/big.rb", "x" * (Jev::StateBuilder::MAX_CONTEXT_BYTES + 10)

    content = build("app/big.rb")[:content]

    assert_includes content, "(truncated)"
    assert_operator content.bytesize, :<, Jev::StateBuilder::MAX_CONTEXT_BYTES + 100
  end
end
