require "test_helper"

module Admin
  # Paginatable cuts every admin index at 25 rows. The CRUD DSL never creates
  # enough rows to render the page controls, so the shared partial is covered
  # here for both sides of the first/last page.
  class PaginationTest < ActionDispatch::IntegrationTest
    include AdminRequestAuth

    def setup
      @task = create_task("Pagination Task", "pagination-task")
    end

    test "index paginates and disables the missing side" do
      # One page is 25 rows, so 30 rows make two pages.
      30.times { |i| @task.requirements.create!(player_level: i + 1) }

      get_auth admin_requirements_path
      assert_response :success
      assert_select "a", text: "Next"
      assert_select "span", text: "Previous"

      get_auth admin_requirements_path(page: 2)
      assert_response :success
      assert_select "a", text: "Previous"
      assert_select "span", text: "Next"
    end

    # The controls are computed from counts, so they stay right even if the
    # offset is wrong: what page two *contains* has to be asserted too.
    test "page two returns the second slice of rows" do
      30.times { |i| @task.requirements.create!(player_level: i + 1) }
      # The index is ordered by id DESC, so page one holds the newest 25 rows.
      ordered = Requirement.order(id: :desc).pluck(:id)

      pages = [ 1, 2 ].map do |page|
        get_auth admin_requirements_path(page: page)
        assert_response :success

        response.body.scan(%r{/admin/requirements/(\d+)}).flatten.map(&:to_i).uniq
      end

      assert_equal [ ordered.first(25), ordered.drop(25) ], pages
      assert_empty pages[0] & pages[1], "page two repeated rows from page one (offset missing)"
    end

    # `per_page` is attacker-controlled. `"abc".to_i` and `""` are 0, which made
    # `(count / 0.0).ceil` raise FloatDomainError, and a negative value reached
    # `limit(-1)`. Every admin index 500d on `?per_page=abc` / `?per_page=0`.
    test "hostile per_page values still render the index" do
      [ "abc", "", "0", "-5", "1.5" ].each do |value|
        get_auth admin_requirements_path(per_page: value)

        assert_response :success, "per_page=#{value.inspect} should still render"
      end
    end
  end
end
