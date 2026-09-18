require "application_system_test_case"

# The task page is the other main reading surface: the unlock path, the
# requirements, the rewards and the follow-up quests. Fixture-only, like every
# system test (see application_system_test_case.rb).
class TaskShowTest < ApplicationSystemTestCase
  test "the hero shows the quest, its trader and the prerequisite count" do
    task = tasks(:one)
    visit task_path(task)

    assert_selector "h1", text: task.full_name
    assert_selector ".crumbs a[href='#{tasks_path}']", text: "Tasks"
    assert_text "Prapor"
    assert_selector ".stat__key", text: /prerequisites/i
  end

  test "the unlock path renders the prerequisite chain" do
    visit task_path(tasks(:one))

    within_section("path-head") { assert_unlock_links }
  end

  test "the requirements panel shows the player level" do
    visit task_path(tasks(:one))

    within "section[aria-labelledby='requirements-head']" do
      assert_text "Player level"
      assert_text "10"
    end
  end

  test "the rewards panel lists the reward groups" do
    visit task_path(tasks(:one))

    within "section[aria-labelledby='rewards-head']" do
      assert_selector ".srcbadge", minimum: 1
    end
  end

  test "the leads-to panel links the follow-up quest" do
    visit task_path(tasks(:one))

    within "section[aria-labelledby='leads-head']" do
      assert_selector "a[href='#{task_path(tasks(:two))}']", text: tasks(:two).full_name
    end
  end

  test "the trader chip filters the listing by that trader" do
    visit task_path(tasks(:one))

    click_on "Prapor quests"

    assert_current_path(/trader=Prapor/, wait: 5)
    assert_selector "h1", text: /tasks/i
  end

  private

  # The page's panels are labelled sections; scoping an assertion to one keeps
  # the same markup from matching elsewhere on the page.
  def within_section(heading_id, &block)
    within("section[aria-labelledby='#{heading_id}']", &block)
  end

  # The unlock path draws the prerequisite chain and links each quest in it.
  def assert_unlock_links
    assert_selector ".timeline-node", minimum: 1
    assert_selector "a[href^='/tasks/']", minimum: 1
  end
end
