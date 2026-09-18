# Shared admin CRUD coverage for the simple resources. The tests are the same
# for every model (index/show/new/create/edit/update/destroy + auth), so they
# are generated from one description. The including test sets `@resource` in
# `setup`; the *_attrs options are lambdas evaluated in that test instance so
# they can reference the setup's records.
module AdminCrudTests
  extend ActiveSupport::Concern

  class_methods do
    def admin_crud_tests(model:, heading:, create_attrs: nil, update_attrs: nil,
                         destroy_attrs: nil, singular: nil, item_select: false, display_count: false,
                         index_columns: [], index_data_fields: [], show_fields: [], edit_fields: [])
      include AdminRequestAuth

      route = "admin_#{model.name.underscore}"
      param_key = model.name.underscore
      index_helper = "#{route}s_path"
      show_helper = "#{route}_path"
      new_helper = "new_#{route}_path"
      edit_helper = "edit_#{route}_path"
      singular ||= heading.singularize

      # The *_attrs options may be a lambda (evaluated in the test instance so it
      # can reference the setup's records) or a plain hash; fall back to the
      # instance variable the including test set.
      define_method(:resolved) do |option, fallback|
        option.respond_to?(:call) ? instance_exec(&option) : (option || fallback)
      end

      test "get index with auth" do
        get_auth send(index_helper)

        assert_response :success
        assert_select "h1", /#{heading}/i
        assert_match(/New #{singular}/i, response.body)
        assert_match(/\(#{model.count}\)/, response.body) if display_count
        index_columns.each { |label| assert_match(/<th[^>]*>#{label}<\/th>/, response.body) }
        index_data_fields.each { |field| assert_match @resource.public_send(field).to_s, response.body }
      end

      test "get show with auth" do
        get_auth send(show_helper, @resource)

        assert_response :success
        assert_match(/Edit/i, response.body)
        assert_match(/Delete/i, response.body)
        show_fields.each do |label, field|
          assert_match(/#{label}/, response.body) if label
          assert_match @resource.public_send(field).to_s, response.body
        end
      end

      test "get new with auth" do
        get_auth send(new_helper)

        assert_response :success
        assert_match(/New #{singular}/i, response.body)
        if item_select
          assert_match(/<select[^>]*name="#{param_key}\[item_id\]"/, response.body)
          assert_match(/<option[^>]*value="#{@item.id}"/, response.body)
        end
      end

      test "create with valid params" do
        assert_difference("#{model.name}.count") do
          post_auth send(index_helper), params: { param_key => resolved(create_attrs, @create_attrs) }
        end

        assert_redirected_to send(show_helper, model.last)
      end

      test "get edit with auth" do
        get_auth send(edit_helper, @resource)

        assert_response :success
        assert_match(/Edit #{singular}/i, response.body)
        edit_fields.each do |field|
          value = @resource.public_send(field)
          assert_match(/name="#{param_key}\[#{field}\]"/, response.body)
          assert_match(/value="#{Regexp.escape(value.to_s)}"/, response.body) unless value.nil?
        end
        if item_select
          selected = /<option[^>]*selected="selected"[^>]*value="#{@resource.item_id}"|<option[^>]*value="#{@resource.item_id}"[^>]*selected="selected"/
          assert_match(selected, response.body)
        end
      end

      test "update with valid params" do
        patch_auth send(show_helper, @resource), params: { param_key => resolved(update_attrs, @update_attrs) }

        assert_redirected_to send(show_helper, @resource)
      end

      test "destroy deletes the record and redirects to index" do
        new_resource = model.create!(resolved(destroy_attrs, @destroy_attrs || @create_attrs))

        assert_difference("#{model.name}.count", -1) do
          delete_auth send(show_helper, new_resource)
        end

        assert_redirected_to send(index_helper)
      end

      # Every action must reject an unauthenticated request. One test over a
      # table of [verb, url, params] instead of seven near-identical tests.
      test "every action requires authentication" do
        [
          [ :get,    send(index_helper), nil ],
          [ :get,    send(show_helper, @resource), nil ],
          [ :get,    send(new_helper), nil ],
          [ :post,   send(index_helper), { param_key => resolved(create_attrs, @create_attrs) } ],
          [ :get,    send(edit_helper, @resource), nil ],
          [ :patch,  send(show_helper, @resource), { param_key => resolved(update_attrs, @update_attrs) } ],
          [ :delete, send(show_helper, @resource), nil ]
        ].each do |verb, url, params|
          public_send(verb, url, **({ params: params } if params))

          assert_response :unauthorized, "#{verb.to_s.upcase} #{url} should require auth"
        end
      end
    end
  end
end
