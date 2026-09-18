require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  include ItemsTestHelpers

  fixtures :all

  # Every test in this file starts by rendering a page and asserting it
  # answered; the pair is not worth repeating.
  def get_ok(path)
    get path
    assert_response :success
  end

  test "should get index" do
    get_ok(tasks_url)
  end

  # The chains page had a controller, a view and tests but no link anywhere, so
  # the only way to reach it was to type the URL.
  test "index links to the task chains page" do
    get tasks_url

    assert_response :success
    assert_select "a[href=?]", chains_tasks_path, text: "Task chains"
  end

  test "index search by full_name returns matching tasks" do
    create_task("The Punisher Part 1", "the-punisher-part-1", given_by: "Prapor")
    create_task("Wet Job Part 6", "wet-job-part-6", given_by: "Peacekeeper")

    get tasks_url(q: "Punisher")

    assert_response :success
    # Must contain Punisher but must NOT contain Wet Job (search filtered)
    assert_match /Punisher/, response.body
    assert_no_match /Wet Job/, response.body
  ensure
    Task.where(name: %w[the-punisher-part-1 wet-job-part-6]).delete_all
  end

  test "index filters by trader" do
    get tasks_url(trader: "Prapor")
    assert_response :success
    assert_select "h2", text: "Task One"
    assert_no_match(/Task Two/, response.body)
  end

  test "index can narrow to the Kappa set" do
    create_task("Kappa Quest", "kappa-quest", given_by: "Prapor", kappa_required: true)
    create_task("Not Kappa Quest", "not-kappa-quest", given_by: "Prapor", kappa_required: false)

    get tasks_url(kappa: "1")

    assert_response :success
    assert_match "Kappa Quest", response.body
    assert_no_match(/Not Kappa Quest/, response.body)
    # The chip keeps the selection visible and reversible.
    assert_select "a[aria-current=?]", "true", text: /Kappa only/
  ensure
    Task.where(name: %w[kappa-quest not-kappa-quest]).delete_all
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

  test "index marks tasks that need keys" do
    key_task = Task.create!(bsg_id: "kt-#{SecureRandom.hex(4)}", full_name: "Keyed Task", name: "keyed-task",
                            given_by: "Prapor",
                            needed_keys: [ { "map_name" => "Customs", "item_id" => nil, "item_name" => "A key" },
                                           { "map_name" => "Customs", "item_id" => nil, "item_name" => "B key" } ])
    plain = Task.create!(bsg_id: "pt-#{SecureRandom.hex(4)}", full_name: "Plain Task", name: "plain-task",
                         given_by: "Prapor")

    get tasks_url

    assert_response :success
    assert_select "a.task-row[href=?]", task_path(key_task), text: /Key ×2/
    assert_select "a.task-row[href=?]", task_path(plain) do
      assert_select ".chip", text: /Key ×/, count: 0
    end
  ensure
    [ key_task, plain ].each(&:destroy)
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
    assert_select ".timeline-node", text: /Task (One|Two)/
    assert_select ".timeline-node", count: 2
  end

  # A previous-task row links the task when it resolves and falls back to a
  # plain chip when it does not (the source has references by name only).
  test "show links resolved prerequisites and chips unresolved ones" do
    previous = create_task("Resolved Previous", "resolved-previous", given_by: "Prapor")
    task = create_task("Prereq Task", "prereq-task", given_by: "Prapor")
    requirement = task.requirements.create!(player_level: 0, trader_level: [])
    requirement.previous_tasks.create!(task: previous, task_name: previous.name)
    requirement.previous_tasks.create!(task: nil, task_name: "ghost-quest")

    get_ok(task_url(task))

    # Scoped to the requirement row: the unlock timeline links the same task,
    # so an unscoped assertion would pass even with this link removed.
    assert_select ".spec__val a[href=?]", task_path(previous), text: "Resolved Previous"
    assert_select ".spec__val span.chip", text: "Ghost Quest"
  ensure
    task&.destroy
    previous&.destroy
  end

  test "show links the quest's own trader and wiki page" do
    get task_url(tasks(:one))

    assert_response :success
    assert_select "a[href=?]", tasks_path(trader: tasks(:one).given_by), text: /quests/
    assert_select "a[href=?]", tasks(:one).wiki_link, text: "Wiki walkthrough"
  end

  test "show marks an alternative prerequisite with or" do
    child = Task.create!(bsg_id: "altc-#{SecureRandom.hex(4)}", full_name: "Alt Child", name: "alt-child", given_by: "Prapor")
    parent = Task.create!(bsg_id: "altp-#{SecureRandom.hex(4)}", full_name: "Alt Parent", name: "alt-parent", given_by: "Prapor")
    child.requirements.create!(player_level: 0)
         .previous_tasks.create!(task: parent, task_name: parent.name, alternative: true)

    get task_url(child)

    assert_response :success
    assert_select ".timeline-node span", text: "or", minimum: 1
  ensure
    child&.destroy
    parent&.destroy
  end

  test "show renders a trader-level requirement with no prerequisites" do
    # Without the timeline (no prerequisites) a trader gate used to appear
    # nowhere on the page.
    task = create_task("Trader Gated", "trader-gated", given_by: "Jaeger")
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

  # The hero's marker chips are the page's "is this quest special" answer.
  test "show marks a Kappa and Lightkeeper quest" do
    task = create_task("Special Quest", "special-quest", given_by: "Prapor",
                       kappa_required: true, lightkeeper_required: true)

    get_ok(task_url(task))

    assert_select ".chip", text: "Kappa required"
    assert_select ".chip", text: "Lightkeeper required"
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
    assert_select "span", text: "×2"                # loose item quantity

    assert_select "h2", text: "Leads to"
    assert_select "a[href=?]", task_path(tasks(:two)), text: "Task Two"
    # The hero also carries a "Leads to" stat with the follow-up count.
    assert_select ".stat__key", text: "Leads to"
    assert_select ".stat__val", text: "1"
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
    bare = create_task("Bare Task", "bare-task", given_by: "Jaeger")

    get_ok(task_url(bare))
    assert_select "h1", text: "Bare Task"
    assert_select "p", text: "No rewards listed."
    assert_select "h2", text: "Unlock path", count: 0
  ensure
    bare&.destroy
  end

  # The chains page renders one panel per trader, ordered by trader name. Task
  # names order the source list (the controller sorts tasks by full_name), so
  # these two new chains are built in an order that disagrees with the trader
  # order — otherwise the assertion would pass on insertion order alone.
  test "chains orders traders by name, not by task order" do
    later = create_chain_task("Alpha Start", "alpha-start", given_by: "Zzz Trader")
    create_chain_task("Alpha Next", "alpha-next", given_by: "Zzz Trader", previous: later)
    sooner = create_chain_task("Beta Start", "beta-start", given_by: "Aaa Trader")
    create_chain_task("Beta Next", "beta-next", given_by: "Aaa Trader", previous: sooner)

    get_ok(chains_tasks_url)

    slugs = css_select("section[aria-labelledby^=chain-]").map { |section| section["aria-labelledby"].sub("chain-", "") }

    assert_includes slugs, "aaa-trader"
    assert_includes slugs, "zzz-trader"
    assert_equal slugs.sort, slugs, "trader panels must be ordered by trader name"
  ensure
    Task.where(full_name: [ "Alpha Start", "Alpha Next", "Beta Start", "Beta Next" ]).destroy_all
  end

  # The index row carries the quest's trader, its follow-up count and the two
  # special markers; none of them were asserted.
  test "index rows show the trader, follow-up count and markers" do
    task = create_task("Marked Quest", "marked-quest", given_by: "Prapor",
                       kappa_required: true, lightkeeper_required: true)
    task.leads_tos.create!(follow_up_task_name: "next-quest")
    task.leads_tos.create!(follow_up_task_name: "another-quest")

    get_ok(tasks_url)

    row = css_select("a.task-row").find { |anchor| anchor.text.include?("Marked Quest") }
    assert row, "the new quest should have a row on the index"

    assert_includes row.text, "Prapor"
    assert_includes row.text, "2 follows"
    assert_equal [ "Kappa", "Lightkeeper" ], row.css(".chip").map(&:text)
  ensure
    task&.destroy
  end

  test "search suggests quests as rows" do
    get search_tasks_url(q: "task one")

    assert_response :success
    assert_select "a[href=?]", task_path(tasks(:one))
  end

  # The suggestion row marks a special quest; Lightkeeper wins over Kappa.
  test "search suggestion rows mark special quests" do
    lightkeeper = create_task("Lighthouse Quest", "lighthouse-quest", given_by: "Prapor",
                              lightkeeper_required: true, kappa_required: true)
    kappa = create_task("Kappa Only Quest", "kappa-only-quest", given_by: "Prapor", kappa_required: true)

    get search_tasks_url(q: "quest")

    assert_response :success
    assert_select "a[href=?]", task_path(lightkeeper) do
      assert_select ".chip", text: "Lighthouse"
    end
    assert_select "a[href=?]", task_path(kappa) do
      assert_select ".chip", text: "Kappa"
    end
  ensure
    Task.where(name: %w[lighthouse-quest kappa-only-quest]).delete_all
  end

  test "search ignores a short query and returns nothing when unmatched" do
    [ "a", "zzzzzzzzzzzz" ].each do |query|
      get search_tasks_url(q: query)
      assert_response :no_content
    end
  end

  test "show renders a quest whose rewards carry nothing" do
    # The controller eager loads the items behind each reward. Empty reward
    # collections left those preloads unused, which Bullet reports and raises
    # on in development, 500ing the page.
    task = create_task("Empty Rewards", "empty-rewards", given_by: "Prapor")
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

  # The page preloads a graph before rendering. A conditional request that is
  # still fresh must answer 304 *before* that work: otherwise Bullet raises on
  # the preloads the skipped view never used (500 in development) and production
  # pays for a graph nobody reads.
  test "show answers a fresh conditional request with 304" do
    task = create_task("Conditional Quest", "conditional-quest")

    get_ok(task_url(task))

    get task_url(task), headers: { "If-None-Match" => response.headers["ETag"] }

    assert_response :not_modified
  ensure
    task&.destroy
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

  # `chains` preloads an unloaded relation, so a 304 returns before the graph is
  # ever iterated — no unused eager loading to trip Bullet.
  test "chains answers a fresh conditional request with 304" do
    get_ok(chains_tasks_url)

    get chains_tasks_url, headers: { "If-None-Match" => response.headers["ETag"] }

    assert_response :not_modified
  end

  test "chains page renders no trader sections for a shapeless graph" do
    Task.all.find_each { |t| t.update_columns(given_by: nil) }

    get_ok(chains_tasks_url)
    assert_select ".timeline-node", count: 0
  end

  # A trader whose deepest chain is a single task has no chain to draw, so the
  # section is skipped rather than rendering a one-node "chain".
  test "chains page omits a trader whose tasks have no prerequisites" do
    lonely = create_task("Lonely Quest", "lonely-quest", given_by: "TestTrader")

    get chains_tasks_url

    assert_response :success
    assert_not_includes response.body, "Lonely Quest"
  ensure
    lonely&.destroy
  end
end
