module AdminTestHelper
  extend ActiveSupport::Concern

  ADMIN_USERNAME = "admin".freeze
  ADMIN_PASSWORD = ENV.fetch("ADMIN_PASSWORD") { "admin" }.freeze

  included do
    setup :admin_login
  end

  def admin_login
    @admin_password = ADMIN_PASSWORD
    @admin_auth_headers = {
      "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(ADMIN_USERNAME, @admin_password)
    }
  end

  def admin_login_unless_authenticated
    return if @admin_auth_headers

    @admin_password = ADMIN_PASSWORD
    @admin_auth_headers = {
      "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(ADMIN_USERNAME, @admin_password)
    }
  end

  def get_with_auth(url, headers: {})
    get url, headers: @admin_auth_headers.merge(headers)
  end

  def post_with_auth(url, params: {}, headers: {})
    post url, params: params, headers: @admin_auth_headers.merge(headers)
  end

  def patch_with_auth(url, params: {}, headers: {})
    patch url, params: params, headers: @admin_auth_headers.merge(headers)
  end

  def put_with_auth(url, params: {}, headers: {})
    put url, params: params, headers: @admin_auth_headers.merge(headers)
  end

  def delete_with_auth(url, headers: {})
    delete url, headers: @admin_auth_headers.merge(headers)
  end

  def assert_content_exists(content, msg = nil)
    msg ||= "Expected content '#{content}' to exist in response"
    assert response.body.include?(content.to_s), msg
  end

  def refute_content_exists(content, msg = nil)
    msg ||= "Expected content '#{content}' NOT to exist in response"
    refute response.body.include?(content.to_s), msg
  end

  def assert_button_exists(text, type: :link)
    case type
    when :link
      assert_match(/href=.*#{text}/, response.body) || assert_match(/>\s*#{Regexp.escape(text)}\s*</, response.body)
    when :button
      assert_match(/<button[^>]*>\s*#{Regexp.escape(text)}\s*<\/button>/, response.body) || assert_match(/type=["']#{text}["']/, response.body)
    when :submit
      assert_match(/type=["']submit["'][^>]*>#{Regexp.escape(text)}/, response.body) || assert_match(/type=["']submit["'][^>]*value=["']#{Regexp.escape(text)}["'"]/, response.body)
    end
  end

  def assert_table_headers(*expected_headers)
    expected_headers.each do |header|
      assert_match(/<th[^>]*>\s*#{Regexp.escape(header)}\s*<\/th>/, response.body, "Expected header '#{header}' not found")
    end
  end

  def assert_table_row_contains(row_index, content)
    rows = response.body.scan(/<tr[^>]*>.*?<\/tr>/m)
    assert row_index < rows.size, "Row #{row_index} does not exist"
    assert rows[row_index].include?(content.to_s), "Expected content '#{content}' in row #{row_index}"
  end

  def assert_pagination_or_limit(count)
    assert_match(/#{count}/, response.body, "Expected count #{count} to be displayed")
  end

  def assert_form_field(field_name, type: :text)
    case type
    when :text, :number
      assert_match(/name=["'][^"']*\[#{field_name}\][^"']*["']/, response.body) || assert_match(/id=["'][^"']*_#{field_name}["']/, response.body)
    when :textarea
      assert_match(/<textarea[^>]*name=["'][^"']*\[#{field_name}\][^"']*["']/, response.body)
    when :checkbox
      assert_match(/type=["']checkbox["'][^>]*name=["'][^"']*\[#{field_name}\][^"']*["']/, response.body)
    end
  end

  def assert_redirect_to_admin_index(model_class)
    assert_redirected_to send("admin_#{model_class.name.underscore.pluralize}_path")
  end

  def assert_redirect_to_admin_show(model)
    assert_redirected_to send("admin_#{model.class.name.underscore}_path", model)
  end

  def create_test_resource(model_class, attributes = {})
    model_class.create!(factory_defaults(model_class).merge(attributes))
  end

  private

  def factory_defaults(model_class)
    case model_class.name
    when "Item"
      { bsg_id: "test_#{SecureRandom.hex(4)}", full_name: "Test Item", short_name: "TI" }
    when "Task"
      { bsg_id: "test_#{SecureRandom.hex(4)}", full_name: "Test Task", name: "Test Task", given_by: "Prapor" }
    when "Requirement"
      { task_id: 1, player_level: 1 }
    when "Reward"
      { task_id: 1, reward_type: "Item" }
    when "LeadsTo"
      { task_id: 1, follow_up_task_id: 2 }
    when "PreviousTask"
      { requirement_id: 1, task_id: 2 }
    when "BarterUnlock"
      { reward_id: 1, item_id: 1, item_name: "Test Item" }
    when "CraftUnlock"
      { reward_id: 1, item_id: 1, item_name: "Test Item", hideout_station: "Workbench", station_level: 1 }
    when "OfferUnlock"
      { reward_id: 1, item_id: 1, item_name: "Test Item", trader_name: "Prapor", trader_level: 1 }
    else
      {}
    end
  end
end
