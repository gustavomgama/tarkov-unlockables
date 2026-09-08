require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
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
end
