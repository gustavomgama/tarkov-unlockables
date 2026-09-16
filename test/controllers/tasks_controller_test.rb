require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  test "should get index" do
    get tasks_url
    assert_response :success
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
    assert_select "h3", text: "Task One"
    assert_no_match(/Task Two/, response.body)
  end

  test "show renders task header and unlock path from the prerequisite graph" do
    get task_url(tasks(:one))

    assert_response :success
    assert_select "h1", text: "Task One"
    assert_select "p", text: /Prapor/

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
