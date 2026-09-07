require "test_helper"

module Admin
  class RewardsControllerTest < ActionDispatch::IntegrationTest
    def setup
      @task = Task.create!(bsg_id: "task#{SecureRandom.hex(4)}", full_name: "Test Task", name: "TT")
      @resource = Reward.first || Reward.create!(task_id: @task.id, reward_type: "Item")
      @admin_password = ENV.fetch("ADMIN_PASSWORD") { "admin" }
      @admin_auth = {
        "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", @admin_password)
      }
    end

    def teardown
    end

    def get_auth(url, **kwargs)
      get url, **kwargs.merge(headers: @admin_auth)
    end

    def post_auth(url, **kwargs)
      post url, **kwargs.merge(headers: @admin_auth)
    end

    def patch_auth(url, **kwargs)
      patch url, **kwargs.merge(headers: @admin_auth)
    end

    def delete_auth(url, **kwargs)
      delete url, **kwargs.merge(headers: @admin_auth)
    end

    test "get index with auth" do
      get_auth admin_rewards_path
      assert_response :success
      assert_select "h1", /Rewards/i
    end

    test "index has new button" do
      get_auth admin_rewards_path
      assert_response :success
      assert_match /New Reward/i, response.body
    end

    test "get show with auth" do
      get_auth admin_reward_path(@resource)
      assert_response :success
    end

    test "show has edit and delete buttons" do
      get_auth admin_reward_path(@resource)
      assert_response :success
      assert_match /Edit/i, response.body
      assert_match /Delete/i, response.body
    end

    test "get new with auth" do
      get_auth new_admin_reward_path
      assert_response :success
      assert_match /New Reward/i, response.body
    end

    test "create with valid params" do
      assert_difference("Reward.count") do
        post_auth admin_rewards_path, params: { reward: { task_id: @task.id, reward_type: "Experience" } }
      end
      assert_redirected_to admin_reward_path(Reward.last)
    end

    test "get edit with auth" do
      get_auth edit_admin_reward_path(@resource)
      assert_response :success
      assert_match /Edit Reward/i, response.body
    end

    test "update with valid params" do
      patch_auth admin_reward_path(@resource), params: { reward: { reward_type: "Cash" } }
      assert_redirected_to admin_reward_path(@resource)
    end

    test "destroy redirects to index" do
      new_resource = Reward.create!(task_id: @task.id, reward_type: "Item")
      delete_auth admin_reward_path(new_resource)
      assert_redirected_to admin_rewards_path
    end

    test "index requires authentication" do
      get admin_rewards_path
      assert_response :unauthorized
    end

    test "show requires authentication" do
      get admin_reward_path(@resource)
      assert_response :unauthorized
    end
  end
end
