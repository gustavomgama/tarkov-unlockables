# Admin CRUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add full CRUD management for all 25 models via a separate admin panel at `/admin` with HTTP Basic Auth.

**Architecture:** Rails admin namespace with 5 controllers, shared admin layout, simple password auth via env var, direct controller actions (no API layer), Turbo/Stimulus for interactivity.

**Tech Stack:** Rails 8, Turbo/Stimulus (existing importmap), Tailwind CSS (existing), no new dependencies.

**Spec:** This plan implements the approved design from conversation.

---

## Global Constraints

- Use existing Tailwind CSS setup (no new CSS framework)
- Use existing Tailwind CSS variables from `app/views/layouts/application.html.erb`
- Follow existing controller patterns from `app/controllers/items_controller.rb`
- Admin auth: `ADMIN_PASSWORD` env var, HTTP Basic Auth
- All admin routes under `/admin` namespace

---

## Task 1: Admin Auth & Layout Foundation

**Files:**
- Create: `app/controllers/admin/application_controller.rb`
- Create: `app/views/admin/layouts/application.html.erb`
- Modify: `config/routes.rb`

**Interfaces:**
- Produces: `Admin::ApplicationController` (auth filter + layout)
- Consumes: `ADMIN_PASSWORD` env var

- [ ] **Step 1: Create admin application controller with HTTP Basic Auth**

```ruby
# app/controllers/admin/application_controller.rb
class Admin::ApplicationController < ApplicationController
  http_basic_authenticate_with(
    name: "admin",
    password: -> { ENV.fetch("ADMIN_PASSWORD", "admin") }
  )

  layout "admin/application"
end
```

- [ ] **Step 2: Create admin layout with sidebar navigation**

```erb
<!-- app/views/admin/layouts/application.html.erb -->
<!DOCTYPE html>
<html lang="en" class="dark">
  <head>
    <title>Admin // Tarkov DB</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "application", "tailwind" %>
    <%= javascript_importmap_tags %>
    <style>
      <%= render "shared/admin_styles" %>
    </style>
  </head>
  <body class="min-h-screen bg-[var(--bg-dark)] flex">
    <aside class="w-64 bg-[var(--bg-panel)] border-r border-[var(--border)] flex-shrink-0">
      <div class="p-4 border-b border-[var(--border)]">
        <%= link_to "Admin", admin_root_path, class: "text-lg font-bold text-[var(--accent)]" %>
      </div>
      <nav class="p-4 space-y-2">
        <div class="text-xs uppercase text-[var(--text-muted)] mb-2">Items</div>
        <%= admin_nav_link("Items", [:admin, Item]) %>
        <%= admin_nav_link("Properties", [:admin, Property]) %>
        <%= admin_nav_link("Slots", [:admin, Slot]) %>

        <div class="text-xs uppercase text-[var(--text-muted)] mt-4 mb-2">Tasks</div>
        <%= admin_nav_link("Tasks", [:admin, Task]) %>
        <%= admin_nav_link("Requirements", [:admin, Requirement]) %>
        <%= admin_nav_link("Rewards", [:admin, Reward]) %>
        <%= admin_nav_link("Leads To", [:admin, LeadsTo]) %>

        <div class="text-xs uppercase text-[var(--text-muted)] mt-4 mb-2">Barters</div>
        <%= admin_nav_link("Barter Unlocks", [:admin, BarterUnlock]) %>

        <div class="text-xs uppercase text-[var(--text-muted)] mt-4 mb-2">Crafts</div>
        <%= admin_nav_link("Craft Unlocks", [:admin, CraftUnlock]) %>

        <div class="text-xs uppercase text-[var(--text-muted)] mt-4 mb-2">Offers</div>
        <%= admin_nav_link("Offer Unlocks", [:admin, OfferUnlock]) %>
      </nav>
    </aside>

    <main class="flex-1 p-8">
      <%= yield %>
    </main>
  </body>
</html>
```

- [ ] **Step 3: Create admin styles partial**

```erb
<!-- app/views/shared/_admin_styles.html.erb -->
:root {
  --bg-dark: #0a0a0a;
  --bg-panel: #12161c;
  --bg-surface: #1a1a1a;
  --bg-elevated: #22252a;
  --text: #e0e0e0;
  --text-bright: #ffffff;
  --text-muted: #888888;
  --accent: #d2af78;
  --accent-hover: #e6c58c;
  --border: #333333;
  --success: #00a700;
  --danger: #cd1e2f;
}
```

- [ ] **Step 4: Create admin helper for nav links**

```ruby
# app/helpers/admin/application_helper.rb
module Admin::ApplicationHelper
  def admin_nav_link(label, controller)
    opts = {}
    opts[:class] = "block px-3 py-2 rounded text-sm text-[var(--text)] hover:bg-[var(--bg-surface)] hover:text-[var(--accent)]"
    opts[:class] += " bg-[var(--bg-surface)] text-[var(--accent)]" if current_page_controller?(controller)
    link_to label, controller, opts
  end

  def current_page_controller?(controller)
    controller = controller.first if controller.is_a?(Array)
    controller_name = controller.name.demodulize.underscore.pluralize
    params[:controller] == "admin/#{controller_name}"
  end
end
```

- [ ] **Step 5: Add admin routes**

```ruby
# config/routes.rb - add admin section
namespace :admin do
  resources :items, :tasks, :properties, :slots, :requirements, :rewards, :leads_tos,
            :barter_unlocks, :craft_unlocks, :offer_unlocks, :previous_tasks
  root to: "dashboard#index"
end

# Also add redirect from /admin to /admin/items
get "/admin", to: redirect("/admin/items")
```

- [ ] **Step 6: Create admin dashboard controller**

```ruby
# app/controllers/admin/dashboard_controller.rb
class Admin::DashboardController < Admin::ApplicationController
  def index
  end
end
```

- [ ] **Step 7: Create admin dashboard view**

```erb
<!-- app/views/admin/dashboard/index.html.erb -->
<div class="text-2xl font-bold text-[var(--text-bright)]">Admin Dashboard</div>
<div class="mt-4 grid grid-cols-3 gap-4">
  <% [{ label: "Items", count: Item.count, model: Item },
      { label: "Tasks", count: Task.count, model: Task },
      { label: "Properties", count: Property.count, model: Property }].each do |stat| %>
    <div class="bg-[var(--bg-panel)] p-4 rounded border border-[var(--border)]">
      <div class="text-[var(--text-muted)] text-sm"><%= stat[:label] %></div>
      <div class="text-2xl font-bold text-[var(--text-bright)]"><%= stat[:count] %></div>
    </div>
  <% end %>
</div>
```

- [ ] **Step 8: Test auth and layout**

Run: `rails server -e development`
Expected: Visiting `/admin/items` prompts for HTTP Basic Auth. After entering correct password, shows admin layout with sidebar.

- [ ] **Step 9: Commit**

---

## Task 2: Generic Admin Controller Concern

**Files:**
- Create: `app/controllers/concerns/admin_crud.rb`
- Create: `app/helpers/admin/table_helper.rb`

**Interfaces:**
- Produces: `AdminCrud` concern for use in all admin controllers
- Consumes: Model class constant passed via `self.resource_class`

- [ ] **Step 1: Create AdminCrud concern**

```ruby
# app/controllers/concerns/admin_crud.rb
module AdminCrud
  extend ActiveSupport::Concern

  class_methods do
    def crud_actions(options = {})
      @resource_class = options[:model] || name.demodulize.sub("Controller", "").singularize.constantize
    end

    def resource_class
      @resource_class
    end
  end

  def index
    @resources = resource_class.all.order(created_at: :desc).limit(100)
  end

  def show
    @resource = resource_class.find(params[:id])
  end

  def new
    @resource = resource_class.new
  end

  def create
    @resource = resource_class.new(resource_params)
    if @resource.save
      redirect_to [:admin, @resource], notice: "#{resource_class.name} created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @resource = resource_class.find(params[:id])
  end

  def update
    @resource = resource_class.find(params[:id])
    if @resource.update(resource_params)
      redirect_to [:admin, @resource], notice: "#{resource_class.name} updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @resource = resource_class.find(params[:id])
    @resource.destroy
    redirect_to [:admin, resource_class], notice: "#{resource_class.name} deleted"
  end

  private

  def resource_params
    params.require(resource_class.name.underscore.to_sym).permit!
  end
end
```

- [ ] **Step 2: Create table helper for admin views**

```ruby
# app/helpers/admin/table_helper.rb
module Admin::TableHelper
  def admin_table(columns, resources)
    tag.table(class: "w-full text-sm") do
      concat tag.thead do
        concat tag.tr do
          columns.each do |col|
            concat tag.th(col[:label], class: "text-left p-2 text-[var(--text-muted)] border-b border-[var(--border)]")
          end
          concat tag.th(class: "text-left p-2 text-[var(--text-muted)] border-b border-[var(--border)]") { "Actions" }
        end
      end
      concat tag.tbody do
        resources.each do |resource|
          concat tag.tr(class: "border-b border-[var(--border-faint)] hover:bg-[var(--bg-surface)]") do
            columns.each do |col|
              concat tag.td(class: "p-2") do
                value = resource.public_send(col[:field])
                if col[:truncate]
                  truncate(value.to_s, length: col[:truncate])
                else
                  value.to_s
                end
              end
            end
            concat tag.td(class: "p-2") do
              link_to("Show", [:admin, resource], class: "text-[var(--accent)] hover:underline") + " | " +
              link_to("Edit", [:edit, :admin, resource], class: "text-[var(--accent)] hover:underline") + " | " +
              button_to("Delete", [:admin, resource], method: :delete, data: { confirm: "Are you sure?" }, class: "text-[var(--danger)] hover:underline bg-transparent border-none cursor-pointer")
            end
          end
        end
      end
    end
  end

  def admin_form_fields(fields, form)
    fields.map do |field|
      content_tag(:div) do
        concat label_tag(field[:name], field[:label], class: "block text-sm text-[var(--text-muted)] mb-1")
        concat case field[:type]
               when :text_area
                 form.text_area(field[:name], class: "w-full bg-[var(--bg-surface)] border border-[var(--border)] rounded p-2 text-[var(--text)]")
               when :number
                 form.number_field(field[:name], class: "w-full bg-[var(--bg-surface)] border border-[var(--border)] rounded p-2 text-[var(--text)]")
               when :checkbox
                 form.check_box(field[:name], class: "")
               else
                 form.text_field(field[:name], class: "w-full bg-[var(--bg-surface)] border border-[var(--border)] rounded p-2 text-[var(--text)]")
               end
      end
    end.join.html_safe
  end
end
```

- [ ] **Step 3: Commit**

---

## Task 3: Admin Items Controller

**Files:**
- Create: `app/controllers/admin/items_controller.rb`
- Create: `app/views/admin/items/index.html.erb`
- Create: `app/views/admin/items/show.html.erb`
- Create: `app/views/admin/items/new.html.erb`
- Create: `app/views/admin/items/edit.html.erb`
- Create: `app/views/admin/items/_form.html.erb`

**Interfaces:**
- Consumes: `AdminCrud` concern, `Item` model with associations

- [ ] **Step 1: Create ItemsController**

```ruby
# app/controllers/admin/items_controller.rb
class Admin::ItemsController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: Item

  private

  def resource_params
    params.require(:item).permit(:bsg_id, :slug, :full_name, :short_name, :categories, :links, :images)
  end
end
```

- [ ] **Step 2: Create items index view**

```erb
<!-- app/views/admin/items/index.html.erb -->
<div class="mb-4 flex justify-between items-center">
  <h1 class="text-2xl font-bold text-[var(--text-bright)]">Items (<%= @resources.count %>)</h1>
  <%= link_to "New Item", [:new, :admin, :item], class: "px-4 py-2 bg-[var(--accent)] text-[var(--bg-dark)] rounded font-bold" %>
</div>

<%= admin_table([
  { label: "BSG ID", field: :bsg_id },
  { label: "Full Name", field: :full_name, truncate: 40 },
  { label: "Short Name", field: :short_name },
  { label: "Categories", field: :categories }
], @resources) %>
```

- [ ] **Step 3: Create items show view**

```erb
<!-- app/views/admin/items/show.html.erb -->
<div class="mb-4">
  <%= link_to "← Back", [:admin, :items], class: "text-[var(--accent)]" %>
</div>

<div class="bg-[var(--bg-panel)] p-6 rounded border border-[var(--border)]">
  <h1 class="text-2xl font-bold text-[var(--text-bright)] mb-4"><%= @resource.full_name %></h1>

  <dl class="grid grid-cols-2 gap-4">
    <div>
      <dt class="text-[var(--text-muted)] text-sm">BSG ID</dt>
      <dd class="text-[var(--text)]"><%= @resource.bsg_id %></dd>
    </div>
    <div>
      <dt class="text-[var(--text-muted)] text-sm">Slug</dt>
      <dd class="text-[var(--text)]"><%= @resource.slug %></dd>
    </div>
    <div>
      <dt class="text-[var(--text-muted)] text-sm">Short Name</dt>
      <dd class="text-[var(--text)]"><%= @resource.short_name %></dd>
    </div>
    <div>
      <dt class="text-[var(--text-muted)] text-sm">Categories</dt>
      <dd class="text-[var(--text)]"><%= @resource.categories.join(", ") %></dd>
    </div>
  </dl>

  <div class="mt-6 flex gap-4">
    <%= link_to "Edit", [:edit, :admin, @resource], class: "px-4 py-2 bg-[var(--bg-surface)] border border-[var(--border)] rounded text-[var(--text)]" %>
    <%= button_to "Delete", [:admin, @resource], method: :delete, data: { confirm: "Are you sure?" }, class: "px-4 py-2 bg-[var(--danger)] text-white rounded" %>
  </div>
</div>
```

- [ ] **Step 4: Create items form partial**

```erb
<!-- app/views/admin/items/_form.html.erb -->
<%= form_with model: [:admin, item], local: true do |form| %>
  <% if item.errors.any? %>
    <div class="mb-4 p-4 bg-[var(--danger)]/10 border border-[var(--danger)] rounded text-[var(--danger)]">
      <ul class="list-disc pl-4">
        <% item.errors.each do |error| %>
          <li><%= error.full_message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="space-y-4">
    <div>
      <%= form.label :bsg_id, class: "block text-sm text-[var(--text-muted)] mb-1" %>
      <%= form.text_field :bsg_id, class: "w-full bg-[var(--bg-surface)] border border-[var(--border)] rounded p-2 text-[var(--text)]" %>
    </div>

    <div>
      <%= form.label :slug, class: "block text-sm text-[var(--text-muted)] mb-1" %>
      <%= form.text_field :slug, class: "w-full bg-[var(--bg-surface)] border border-[var(--border)] rounded p-2 text-[var(--text)]" %>
    </div>

    <div>
      <%= form.label :full_name, class: "block text-sm text-[var(--text-muted)] mb-1" %>
      <%= form.text_field :full_name, class: "w-full bg-[var(--bg-surface)] border border-[var(--border)] rounded p-2 text-[var(--text)]" %>
    </div>

    <div>
      <%= form.label :short_name, class: "block text-sm text-[var(--text-muted)] mb-1" %>
      <%= form.text_field :short_name, class: "w-full bg-[var(--bg-surface)] border border-[var(--border)] rounded p-2 text-[var(--text)]" %>
    </div>

    <div>
      <%= form.label :categories, "Categories (comma-separated)", class: "block text-sm text-[var(--text-muted)] mb-1" %>
      <%= form.text_field :categories, value: item.categories.join(", "), class: "w-full bg-[var(--bg-surface)] border border-[var(--border)] rounded p-2 text-[var(--text)]" %>
    </div>
  </div>

  <div class="mt-6 flex gap-4">
    <%= form.submit class: "px-4 py-2 bg-[var(--accent)] text-[var(--bg-dark)] rounded font-bold cursor-pointer" %>
    <%= link_to "Cancel", [:admin, :items], class: "px-4 py-2 bg-[var(--bg-surface)] border border-[var(--border)] rounded text-[var(--text)]" %>
  </div>
<% end %>
```

- [ ] **Step 5: Create new/edit views**

```erb
<!-- app/views/admin/items/new.html.erb -->
<div class="mb-4">
  <%= link_to "← Back", [:admin, :items], class: "text-[var(--accent)]" %>
</div>
<h1 class="text-2xl font-bold text-[var(--text-bright)] mb-6">New Item</h1>
<%= render "form", item: @resource %>
```

```erb
<!-- app/views/admin/items/edit.html.erb -->
<div class="mb-4">
  <%= link_to "← Back", [:admin, @resource], class: "text-[var(--accent)]" %>
</div>
<h1 class="text-2xl font-bold text-[var(--text-bright)] mb-6">Edit Item</h1>
<%= render "form", item: @resource %>
```

- [ ] **Step 6: Commit**

---

## Task 4: Admin Tasks Controller

**Files:**
- Create: `app/controllers/admin/tasks_controller.rb`
- Create: `app/views/admin/tasks/index.html.erb`
- Create: `app/views/admin/tasks/show.html.erb`
- Create: `app/views/admin/tasks/new.html.erb`
- Create: `app/views/admin/tasks/edit.html.erb`
- Create: `app/views/admin/tasks/_form.html.erb`

**Interfaces:**
- Consumes: `AdminCrud` concern, `Task` model

- [ ] **Step 1: Create TasksController**

```ruby
# app/controllers/admin/tasks_controller.rb
class Admin::TasksController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: Task

  private

  def resource_params
    params.require(:task).permit(:bsg_id, :full_name, :name, :wiki_link, :given_by, :kappa_required, :lightkeeper_required)
  end
end
```

- [ ] **Step 2-5: Create views (index, show, new, edit, form)**

Same pattern as Items but for Task model. Fields: `bsg_id`, `full_name`, `name`, `wiki_link`, `given_by`, `kappa_required`, `lightkeeper_required`.

- [ ] **Step 6: Commit**

---

## Task 5: Admin Properties Controller

**Files:**
- Create: `app/controllers/admin/properties_controller.rb`
- Create: `app/views/admin/properties/index.html.erb`
- Create: `app/views/admin/properties/show.html.erb`
- Create: `app/views/admin/properties/new.html.erb`
- Create: `app/views/admin/properties/edit.html.erb`
- Create: `app/views/admin/properties/_form.html.erb`

**Interfaces:**
- Consumes: `AdminCrud` concern, `Property` model

- [ ] **Step 1: Create PropertiesController**

```ruby
# app/controllers/admin/properties_controller.rb
class Admin::PropertiesController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: Property

  private

  def resource_params
    params.require(:property).permit(
      :item_id, :properties_type, :allowed_ammo, :ammo_type, :armor_slots,
      :armor_type, :base_item, :caliber, :armor_class, :damage, :default,
      :default_ammo, :default_preset, :penetration_power, :presets,
      :slash_damage, :stab_damage, :category, :zones
    )
  end
end
```

- [ ] **Step 2-5: Create views (index, show, new, edit, form)**

Fields for form: `item_id`, `properties_type`, `armor_class`, `armor_type`, `caliber`, `damage`, `penetration_power`, `category`.

- [ ] **Step 6: Commit**

---

## Task 6: Admin Slots Controller

**Files:**
- Create: `app/controllers/admin/slots_controller.rb`
- Create: `app/views/admin/slots/` (index, show, new, edit, form)

**Interfaces:**
- Consumes: `AdminCrud` concern, `Slot` model

- [ ] **Step 1: Create SlotsController**

```ruby
# app/controllers/admin/slots_controller.rb
class Admin::SlotsController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: Slot

  private

  def resource_params
    params.require(:slot).permit(:property_id, :name_id, :required, :allowed_items, :allowed_categories, :excluded_categories, :excluded_items)
  end
end
```

- [ ] **Step 2-5: Create views**

- [ ] **Step 6: Commit**

---

## Task 7: Admin Requirements, Rewards, LeadsTo Controllers

**Files:**
- Create: `app/controllers/admin/requirements_controller.rb` + views
- Create: `app/controllers/admin/rewards_controller.rb` + views
- Create: `app/controllers/admin/leads_tos_controller.rb` + views

**Interfaces:**
- Consumes: `AdminCrud` concern

- [ ] **Step 1: RequirementsController**

```ruby
# app/controllers/admin/requirements_controller.rb
class Admin::RequirementsController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: Requirement

  private

  def resource_params
    params.require(:requirement).permit(:task_id, :player_level, :previous_tasks_count)
  end
end
```

- [ ] **Step 2: RewardsController**

```ruby
# app/controllers/admin/rewards_controller.rb
class Admin::RewardsController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: Reward

  private

  def resource_params
    params.require(:reward).permit(:task_id, :reward_type)
  end
end
```

- [ ] **Step 3: LeadsTosController**

```ruby
# app/controllers/admin/leads_tos_controller.rb
class Admin::LeadsTosController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: LeadsTo

  private

  def resource_params
    params.require(:leads_to).permit(:task_id, :follow_up_task_id, :follow_up_task_name)
  end
end
```

- [ ] **Step 4-9: Create views for all three controllers**

- [ ] **Step 10: Commit**

---

## Task 8: Admin Barter/Craft/Offer Controllers

**Files:**
- Create: `app/controllers/admin/barter_unlocks_controller.rb` + views
- Create: `app/controllers/admin/craft_unlocks_controller.rb` + views
- Create: `app/controllers/admin/offer_unlocks_controller.rb` + views

**Interfaces:**
- Consumes: `AdminCrud` concern

- [ ] **Step 1: BarterUnlocksController**

```ruby
# app/controllers/admin/barter_unlocks_controller.rb
class Admin::BarterUnlocksController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: BarterUnlock

  private

  def resource_params
    params.require(:barter_unlock).permit(:reward_id, :item_id, :item_name)
  end
end
```

- [ ] **Step 2: CraftUnlocksController**

```ruby
# app/controllers/admin/craft_unlocks_controller.rb
class Admin::CraftUnlocksController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: CraftUnlock

  private

  def resource_params
    params.require(:craft_unlock).permit(:reward_id, :item_id, :item_name, :hideout_station, :station_level)
  end
end
```

- [ ] **Step 3: OfferUnlocksController**

```ruby
# app/controllers/admin/offer_unlocks_controller.rb
class Admin::OfferUnlocksController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: OfferUnlock

  private

  def resource_params
    params.require(:offer_unlock).permit(:reward_id, :item_id, :item_name, :trader_name, :trader_level)
  end
end
```

- [ ] **Step 4-9: Create views for all three**

- [ ] **Step 10: Commit**

---

## Task 9: PreviousTasks Controller

**Files:**
- Create: `app/controllers/admin/previous_tasks_controller.rb` + views

- [ ] **Step 1: PreviousTasksController**

```ruby
# app/controllers/admin/previous_tasks_controller.rb
class Admin::PreviousTasksController < Admin::ApplicationController
  include AdminCrud
  crud_actions model: PreviousTask

  private

  def resource_params
    params.require(:previous_task).permit(:requirement_id, :task_id, :task_name)
  end
end
```

- [ ] **Step 2-5: Create views**

- [ ] **Step 6: Commit**

---

## Task 10: Admin Test

**Files:**
- Create: `test/controllers/admin/items_controller_test.rb`
- Create: `test/controllers/admin/tasks_controller_test.rb`

**Interfaces:**
- Consumes: Existing test framework (minitest)

- [ ] **Step 1: Create ItemsController test**

```ruby
# test/controllers/admin/items_controller_test.rb
require "test_helper"

module Admin
  class ItemsControllerTest < ActionDispatch::IntegrationTest
    def setup
      @item = items(:one)
    end

    test "should get index" do
      get admin_items_url
      assert_response :success
    end

    test "should get show" do
      get admin_item_url(@item)
      assert_response :success
    end

    test "should get new" do
      get new_admin_item_url
      assert_response :success
    end

    test "should create item" do
      assert_difference("Item.count") do
        post admin_items_url, params: { item: { bsg_id: "new123", full_name: "New Item", short_name: "NI" } }
      end
      assert_redirected_to admin_item_url(Item.last)
    end

    test "should get edit" do
      get edit_admin_item_url(@item)
      assert_response :success
    end

    test "should update item" do
      patch admin_item_url(@item), params: { item: { full_name: "Updated Name" } }
      assert_redirected_to admin_item_url(@item)
      @item.reload
      assert_equal "Updated Name", @item.full_name
    end

    test "should destroy item" do
      assert_difference("Item.count", -1) do
        delete admin_item_url(@item)
      end
      assert_redirected_to admin_items_url
    end
  end
end
```

- [ ] **Step 2: Create TasksController test (same pattern)**

- [ ] **Step 3: Run tests**

Run: `rails test test/controllers/admin/`
Expected: All tests pass

- [ ] **Step 4: Commit**

---

## Task Order Summary

| # | Task | Hours |
|---|------|-------|
| 1 | Admin Auth & Layout Foundation | 1 |
| 2 | Generic AdminCrud Concern | 0.5 |
| 3 | Admin Items Controller + Views | 1 |
| 4 | Admin Tasks Controller + Views | 0.5 |
| 5 | Admin Properties Controller + Views | 0.5 |
| 6 | Admin Slots Controller + Views | 0.5 |
| 7 | Admin Requirements/Rewards/LeadsTos + Views | 0.5 |
| 8 | Admin BarterUnlocks/CraftUnlocks/OfferUnlocks + Views | 0.5 |
| 9 | Admin PreviousTasks + Views | 0.25 |
| 10 | Admin Tests | 1 |

**Total estimated: ~6 hours**
