# Shared fixtures/assertions for the items controller tests, split across
# items_controller_test (index/search), items_controller_show_test and
# items_controller_filter_test.
module ItemsTestHelpers
  # Asserts the index renders exactly the expected item links and none of the
  # excluded names, under the given filters.
  def assert_filtered_items(filters, expected:, excluded: [])
    get items_url(filters: filters)

    assert_response :success
    Array(expected).each { |text| assert_select "td a", text: text }
    Array(excluded).each { |text| assert_no_match(/#{Regexp.escape(text)}/, response.body) }
  end

  # Asserts the index search renders the expected rows and hides the others.
  def assert_index_search(query, expected:, excluded: [], selector: "td a")
    get items_url(q: query)

    assert_response :success
    Array(expected).each { |text| assert_select selector, text: text }
    Array(excluded).each { |text| assert_no_match(/#{Regexp.escape(text)}/, response.body) }
  end

  # Creates a task, optionally chained behind another via a previous_tasks row.
  def create_chain_task(full_name, name, given_by: "Peacekeeper", player_level: 0, trader_level: [], previous: nil)
    task = Task.create!(bsg_id: "#{SecureRandom.hex(6)}", full_name: full_name, name: name, given_by: given_by)
    requirement = task.requirements.create!(player_level: player_level, trader_level: trader_level)
    requirement.previous_tasks.create!(task: previous, task_name: previous.name) if previous
    task
  end

  # Gives a task a finish reward that offers the item to the player.
  def unlock_via_task(task, item, trader_name: "peacekeeper", trader_level: "4")
    task.rewards.create!(reward_type: "finish_rewards")
        .offer_unlocks.create!(item_id: item.id, item_name: item.full_name, trader_name: trader_name, trader_level: trader_level)
  end

  # Creates a task-gated item: a task whose finish reward offers the item.
  def create_task_gated_item(full_name, task_name: "Gate Task")
    item = create_item(full_name)
    task = create_chain_task(task_name, task_name.parameterize, given_by: "Prapor")
    unlock_via_task(task, item, trader_name: "Prapor", trader_level: 1)
    [ item, task ]
  end

  # Removes an item, its unlock rows and the tasks built for the test.
  def destroy_unlock_fixtures(item, tasks)
    OfferUnlock.where(item_id: item&.id).destroy_all
    task_ids = Array(tasks).compact.map(&:id)
    PreviousTask.where(task_id: task_ids).update_all(task_id: nil)
    Reward.where(task_id: task_ids).destroy_all
    item&.item_currencies&.destroy_all
    Array(tasks).each { |task| task&.destroy }
    item&.destroy
  end

  # Renders an item of the given STI class and asserts its stats labels show.
  def assert_stats_partial(klass, data:, labels:, name: "Stats Item")
    item = create_item(name, klass: klass, data: data)

    get item_url(item)
    assert_response :success
    labels.each { |label| assert_select "dt", text: label }
  ensure
    item&.destroy
  end
  # A barter/craft unlock row feeding +item+, with one requirement row that
  # consumes it (+count+ of it). Used by the "Used in" and query-budget tests.
  # A barter/craft that consumes +item+. The "Used in" panel reads the item's
  # own requirement rows (item_barter_requirements / item_hideout_requirements),
  # which hang off the ItemBarter/ItemHideout row — the same shape the datastore
  # importer builds.
  def build_used_in_unlock(reward, item, prefix, requirement:, count:, unlock: {})
    reward.public_send("#{prefix}_unlocks").create!(item: item, item_name: item.full_name, **unlock)
    # A craft is an ItemHideout row; a barter is an ItemBarter row. Each owns
    # the requirement rows the "Used in" panel reads.
    owner_assoc, requirement_assoc = if prefix == :craft
      [ :item_hideouts, :item_hideout_requirements ]
    else
      [ :item_barters, :item_barter_requirements ]
    end
    owner = item.public_send(owner_assoc).create!(**requirement)
    owner.public_send(requirement_assoc)
         .create!(item: item, item_name: item.full_name, count: count)
  end
end
