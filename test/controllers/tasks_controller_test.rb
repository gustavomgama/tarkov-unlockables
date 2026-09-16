require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  test "should get index" do
    get tasks_url
    assert_response :success
    assert_select "a[href=?]", chains_tasks_path, text: "Task chains"
  end

  test "index search by full_name returns matching tasks" do
    task1 = Task.create!(bsg_id: "st1_#{SecureRandom.hex(4)}", full_name: "The Punisher Part 1", name: "the-punisher-part-1", given_by: "Prapor")
    task2 = Task.create!(bsg_id: "st2_#{SecureRandom.hex(4)}", full_name: "Wet Job Part 6", name: "wet-job-part-6", given_by: "Peacekeeper")

    get tasks_url(q: "Punisher")
    assert_response :success
    # Must contain Punisher but must NOT contain Wet Job (search filtered)
    assert_match /Punisher/, response.body
    assert_no_match /Wet Job/, response.body
  ensure
    task1&.destroy
    task2&.destroy
  end

  test "index filters by trader" do
    get tasks_url(trader: "Prapor")
    assert_response :success
    assert_select "h2", text: "Task One"
    assert_no_match(/Task Two/, response.body)
  end

  test "index can narrow to the Kappa set" do
    kappa = Task.create!(bsg_id: "k+#{SecureRandom.hex(4)}", full_name: "Kappa Quest", name: "kappa-quest", given_by: "Prapor", kappa_required: true)
    other = Task.create!(bsg_id: "n+#{SecureRandom.hex(4)}", full_name: "Not Kappa Quest", name: "not-kappa-quest", given_by: "Prapor", kappa_required: false)

    get tasks_url(kappa: "1")

    assert_response :success
    assert_match "Kappa Quest", response.body
    assert_no_match(/Not Kappa Quest/, response.body)
    # The chip keeps the selection visible and reversible.
    assert_select "a[aria-current=?]", "true", text: /Kappa only/
  ensure
    Task.where(id: [ kappa&.id, other&.id ]).delete_all
  end

  test "index filters by map and the task page links back to the map" do
    task = Task.create!(bsg_id: "mp-#{SecureRandom.hex(4)}", full_name: "Customs Job", name: "customs-job",
                        given_by: "Prapor", map_name: "Customs")
    other = Task.create!(bsg_id: "mp2-#{SecureRandom.hex(4)}", full_name: "Woods Job", name: "woods-job",
                         given_by: "Prapor", map_name: "Woods")

    get tasks_url(map: "Customs")

    assert_response :success
    assert_match "Customs Job", response.body
    assert_no_match(/Woods Job/, response.body)
    assert_select "nav[aria-label='Filter by map'] a[aria-current='true']", text: "Customs"

    get task_url(task)

    assert_response :success
    assert_select "a[href=?]", tasks_path(map: "Customs"), text: "Customs quests"
  ensure
    Task.where(id: [ task&.id, other&.id ]).delete_all
  end

  test "show renders task header and unlock path from the prerequisite graph" do
    get task_url(tasks(:one))

    assert_response :success
    assert_select "h1", text: "Task One"
    assert_select "p", text: /Prapor/
    assert_select "a[href=?]", trader_path("prapor"), text: "Prapor"

    # requirement + previous-task link (Task One requires Task Two)
    assert_select "dt", text: "Player level"
    assert_select "dd", text: "10"
    assert_select "dt", text: "Previous tasks"
    assert_select "a[href=?]", task_path(tasks(:two)), text: "Task Two"

    # unlock timeline renders each node in the chain
    assert_select "h2", text: "Unlock path"
    assert_select ".timeline-node", text: /Task Two/
    assert_select ".timeline-node", text: /Task One/
  end

  test "show links the quest's own trader and wiki page" do
    get task_url(tasks(:one))

    assert_response :success
    assert_select "a[href=?]", tasks_path(trader: tasks(:one).given_by), text: /quests/
    assert_select "a[href=?]", tasks(:one).wiki_link, text: "Wiki walkthrough"
  end

  test "show renders a trader-level requirement with no prerequisites" do
    # Without the timeline (no prerequisites) a trader gate used to appear
    # nowhere on the page.
    task = Task.create!(bsg_id: "tl-#{SecureRandom.hex(4)}", full_name: "Trader Gated", name: "trader-gated", given_by: "Jaeger")
    task.requirements.create!(player_level: 0, trader_level: [ { "trader_name" => "jaeger", "trader_level" => "4" } ])

    get task_url(task)

    assert_response :success
    assert_select "section[aria-labelledby=requirements-head]" do
      assert_select "dt", text: "Trader"
      assert_select "dd", text: "Jaeger LL4"
    end
    assert_select "h2", text: "Unlock path", count: 0
  ensure
    task&.destroy
  end

  test "show renders every reward type and leads-to" do
    get task_url(tasks(:one))

    assert_response :success
    assert_select "h2", text: "Rewards"
    # loose item, offer, barter and craft all point at the same fixture item
    assert_select "a[href=?]", item_path(items(:one)), minimum: 1, text: "Test Item One"
    assert_select "span", text: /Prapor LL2/        # offer unlock
    assert_select "span", text: /Workbench Lv\.1/   # craft unlock

    assert_select "h2", text: "Leads to"
    assert_select "a[href=?]", task_path(tasks(:two)), text: "Task Two"
  end

  test "show lists the trader offers the quest unlocks" do
    task = Task.create!(bsg_id: "gate-#{SecureRandom.hex(4)}", full_name: "Gate Quest", name: "gate-quest", given_by: "Therapist")
    item = Item.create!(bsg_id: "gate-item-#{SecureRandom.hex(4)}", full_name: "Gated Salewa", short_name: "GS")
    item.item_currencies.create!(trader: "Therapist", currency: "RUB", min_trader_level: 3,
                                 task_unlock: true, task: task)

    get task_url(task)

    assert_response :success
    assert_select "h2", text: "Unlocks trader offers"
    assert_select "a[href=?]", item_path(item), text: "Gated Salewa"
    assert_select "span", text: /Therapist LL3/
  ensure
    item&.item_currencies&.destroy_all
    item&.destroy
    task&.destroy
  end

  test "show lists the task objectives in source order" do
    task = Task.create!(bsg_id: "obj-#{SecureRandom.hex(4)}", full_name: "Objective Quest", name: "objective-quest", given_by: "Prapor")
    item = Item.create!(bsg_id: "obj-i-#{SecureRandom.hex(4)}", full_name: "Hand-in Widget", short_name: "HW")
    objective = task.task_objectives.create!(objective_id: "o1", objective_type: "giveItem",
                                             description: "Hand over 3 Salewas", count: 3, position: 0, optional: true)
    objective.task_objective_items.create!(item: item, item_name: item.full_name)
    task.task_objectives.create!(objective_id: "o2", objective_type: "visit", description: "Visit Customs", position: 1)

    get task_url(task)

    assert_response :success
    assert_select "section[aria-labelledby=objectives-head]" do
      assert_select "h2", text: "Objectives"
      assert_select ".srcrow", text: /Hand over 3 Salewas/
      assert_select ".srcrow", text: /Visit Customs/
      assert_select "a[href=?]", item_path(item), text: "Hand-in Widget"
    end
    assert_operator response.body.index("Hand over 3 Salewas"), :<, response.body.index("Visit Customs")
  ensure
    task&.destroy
    item&.destroy
  end

  test "show reads the quest XP and faction" do
    task = Task.create!(bsg_id: "xp-#{SecureRandom.hex(4)}", full_name: "XP Quest", name: "xp-quest",
                        given_by: "Prapor", experience: 12_345, faction: "BEAR")

    get task_url(task)

    assert_response :success
    assert_select ".stat", text: /12,345/
    assert_select ".chip", text: /BEAR only/
  ensure
    task&.destroy
  end

  test "show lists the keys a quest needs, grouped by map" do
    task = Task.create!(bsg_id: "key-#{SecureRandom.hex(4)}", full_name: "Key Quest", name: "key-quest",
                        given_by: "Prapor",
                        needed_keys: [ { "map_name" => "Shoreline", "item_id" => nil,
                                         "item_name" => "Dorm room 306 key" } ])

    get task_url(task)

    assert_response :success
    assert_select "section[aria-labelledby=keys-head]" do
      assert_select "h2", text: "Keys needed"
      assert_select "dt", text: "Shoreline"
      assert_select ".chip", text: "Dorm room 306 key"
    end
  ensure
    task&.destroy
  end

  test "show renders standing and skill rewards" do
    task = Task.create!(bsg_id: "std-#{SecureRandom.hex(4)}", full_name: "Standing Quest", name: "standing-quest",
                        given_by: "Prapor")
    task.rewards.create!(reward_type: "finish_rewards",
                         data: { "trader_standing" => [ { "trader_slug" => "therapist", "standing" => 0.15 } ],
                                 "skill_level_reward" => [ { "skill" => "Strength", "level" => 2 } ] })

    get task_url(task)

    assert_response :success
    assert_select ".srcrow", text: /Standing/
    assert_select ".srcrow", text: /Therapist \+0.15 rep/
    assert_select ".srcrow", text: /Strength level 2/
  ensure
    task&.destroy
  end

  test "show renders gracefully when a task has no requirements or rewards" do
    bare = Task.create!(bsg_id: "bare_#{SecureRandom.hex(4)}", full_name: "Bare Task", name: "bare-task", given_by: "Jaeger")

    get task_url(bare)
    assert_response :success
    assert_select "h1", text: "Bare Task"
    assert_select "p", text: "No rewards listed."
    assert_select "h2", text: "Unlock path", count: 0
  ensure
    bare&.destroy
  end

  test "search suggests quests as rows" do
    get search_tasks_url(q: "task one")

    assert_response :success
    assert_select "a[href=?]", task_path(tasks(:one))
  end

  test "search ignores a short query and returns nothing when unmatched" do
    get search_tasks_url(q: "a")
    assert_response :no_content

    get search_tasks_url(q: "zzzzzzzzzzzz")
    assert_response :no_content
  end

  test "show renders a quest whose rewards carry nothing" do
    # The controller eager loads the items behind each reward. Empty reward
    # collections left those preloads unused, which Bullet reports and raises
    # on in development, 500ing the page.
    task = Task.create!(bsg_id: "empty-#{SecureRandom.hex(4)}", full_name: "Empty Rewards", name: "empty-rewards", given_by: "Prapor")
    task.rewards.create!(reward_type: "start_rewards")
    task.rewards.create!(reward_type: "finish_rewards")

    get task_url(task)

    assert_response :success
    assert_select "h1", text: "Empty Rewards"
    assert_select "p", text: "No rewards listed."
  ensure
    task&.destroy
  end

  test "show returns 404 for a missing task" do
    get task_url(id: 999_999_999)
    assert_response :not_found
    assert_select "h1", text: "404"
  end

  test "chains groups each trader's deepest prerequisite chain" do
    get chains_tasks_url

    assert_response :success
    assert_select "h1", text: "Task chains"
    # fixture graph: Task One (Prapor) <-> Task Two (Therapist), both 2-deep
    assert_select "h2", text: "Prapor"
    assert_select "h2", text: "Therapist"
    assert_select ".timeline-node", text: /Task Two/
  end

  test "chains page renders no trader sections for a shapeless graph" do
    Task.all.find_each { |t| t.update_columns(given_by: nil) }

    get chains_tasks_url
    assert_response :success
    assert_select ".timeline-node", count: 0
  end
end
