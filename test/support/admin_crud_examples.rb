module AdminCrudExamples
  extend ActiveSupport::Concern

  module SharedExamples
    def admin_index_page(model_class, index_columns: [])
      context "#{model_class.name} Index Page" do
        should "get index with auth" do
          get_with_auth send("admin_#{model_class.name.underscore.pluralize}_path")

          assert_response :success
          assert_select "h1", /#{model_class.name}s/i
        end

        should "display count of resources" do
          get_with_auth send("admin_#{model_class.name.underscore.pluralize}_path")

          assert_response :success
          count = model_class.count
          assert_match /\(#{count}\)/, response.body
        end

        should "have new button" do
          get_with_auth send("admin_#{model_class.name.underscore.pluralize}_path")

          assert_response :success
          assert_match /New #{model_class.name}/i, response.body
        end

        should "not allow access without auth" do
          get send("admin_#{model_class.name.underscore.pluralize}_path")

          assert_response :unauthorized
        end

        if index_columns.any?
          should "display correct table headers" do
            get_with_auth send("admin_#{model_class.name.underscore.pluralize}_path")

            assert_response :success
            index_columns.each do |col|
              assert_match /<th[^>]*>#{col[:label]}/i, response.body
            end
          end

          should "display resource data in table" do
            resource = create_test_resource(model_class)

            get_with_auth send("admin_#{model_class.name.underscore.pluralize}_path")

            assert_response :success
            index_columns.each do |col|
              value = resource.public_send(col[:field])
              next if value.nil? || (value.respond_to?(:empty?) && value.empty?)
              assert_match value.to_s, response.body
            end
          end
        end
      end
    end

    def admin_show_page(model_class, show_fields: [])
      context "#{model_class.name} Show Page" do
        should "get show with auth" do
          resource = create_test_resource(model_class)
          get_with_auth send("admin_#{model_class.name.underscore}_path", resource)

          assert_response :success
        end

        should "display all field values" do
          resource = create_test_resource(model_class)
          get_with_auth send("admin_#{model_class.name.underscore}_path", resource)

          assert_response :success
          show_fields.each do |field|
            value = resource.public_send(field)
            next if value.nil?
            if value.is_a?(Array) && value.empty?
              next
            elsif value.is_a?(Array)
              assert_match value.join(", "), response.body
            else
              assert_match value.to_s, response.body
            end
          end
        end

        should "have edit button" do
          resource = create_test_resource(model_class)
          get_with_auth send("admin_#{model_class.name.underscore}_path", resource)

          assert_response :success
          assert_match /Edit/i, response.body
        end

        should "have delete button" do
          resource = create_test_resource(model_class)
          get_with_auth send("admin_#{model_class.name.underscore}_path", resource)

          assert_response :success
          assert_match /Delete/i, response.body
        end

        should "not allow access without auth" do
          resource = create_test_resource(model_class)
          get send("admin_#{model_class.name.underscore}_path", resource)

          assert_response :unauthorized
        end
      end
    end

    def admin_new_page(model_class, form_fields: [])
      context "#{model_class.name} New Page" do
        should "get new with auth" do
          get_with_auth send("new_admin_#{model_class.name.underscore}_path")

          assert_response :success
          assert_match /New #{model_class.name}/i, response.body
        end

        should "display form with all fields" do
          get_with_auth send("new_admin_#{model_class.name.underscore}_path")

          assert_response :success
          form_fields.each do |field|
            assert_match /name=["'][^"']*\[#{field}\]/, response.body, "Expected field '#{field}' in form"
          end
        end

        should "not allow access without auth" do
          get send("new_admin_#{model_class.name.underscore}_path")

          assert_response :unauthorized
        end
      end
    end

    def admin_create(model_class, valid_attributes:, invalid_attributes: {})
      context "#{model_class.name} Create" do
        should "create with valid params and redirect to show" do
          assert_difference("#{model_class.name}.count") do
            post_with_auth send("admin_#{model_class.name.underscore.pluralize}_path"),
                          params: { model_class.name.underscore => valid_attributes }
          end

          assert_redirect_to_admin_show(model_class.last)
        end

        should "re-render new form with invalid params" do
          post_with_auth send("admin_#{model_class.name.underscore.pluralize}_path"),
                        params: { model_class.name.underscore => invalid_attributes }

          assert_response :unprocessable_entity
          assert_match /New #{model_class.name}/i, response.body
        end

        should "not allow access without auth" do
          post send("admin_#{model_class.name.underscore.pluralize}_path"),
               params: { model_class.name.underscore => valid_attributes }

          assert_response :unauthorized
        end
      end
    end

    def admin_edit_page(model_class, form_fields: [])
      context "#{model_class.name} Edit Page" do
        should "get edit with auth" do
          resource = create_test_resource(model_class)
          get_with_auth send("edit_admin_#{model_class.name.underscore}_path", resource)

          assert_response :success
          assert_match /Edit #{model_class.name}/i, response.body
        end

        should "display form pre-populated with current values" do
          resource = create_test_resource(model_class)
          get_with_auth send("edit_admin_#{model_class.name.underscore}_path", resource)

          assert_response :success
          form_fields.each do |field|
            value = resource.public_send(field)
            next if value.nil?
            if value.is_a?(Array) && !value.empty?
              assert_match value.join("\n"), response.body
            else
              assert_match value.to_s, response.body
            end
          end
        end

        should "not allow access without auth" do
          resource = create_test_resource(model_class)
          get send("edit_admin_#{model_class.name.underscore}_path", resource)

          assert_response :unauthorized
        end
      end
    end

    def admin_update(model_class, update_attributes:)
      context "#{model_class.name} Update" do
        should "update with valid params and redirect to show" do
          resource = create_test_resource(model_class)
          patch_with_auth send("admin_#{model_class.name.underscore}_path", resource),
                          params: { model_class.name.underscore => update_attributes }

          assert_redirect_to_admin_show(resource)
          resource.reload
          update_attributes.each do |key, value|
            actual = resource.public_send(key)
            if value.is_a?(Array)
              assert_equal value.sort, actual.sort, "Field #{key} not updated correctly"
            else
              assert_equal value, actual, "Field #{key} not updated correctly"
            end
          end
        end

        should "re-render edit form with invalid params" do
          resource = create_test_resource(model_class)
          patch_with_auth send("admin_#{model_class.name.underscore}_path", resource),
                          params: { model_class.name.underscore => { invalid: true } }

          assert_response :unprocessable_entity
          assert_match /Edit #{model_class.name}/i, response.body
        end

        should "not allow access without auth" do
          resource = create_test_resource(model_class)
          patch send("admin_#{model_class.name.underscore}_path", resource),
                params: { model_class.name.underscore => update_attributes }

          assert_response :unauthorized
        end
      end
    end

    def admin_destroy(model_class)
      context "#{model_class.name} Destroy" do
        should "destroy and redirect to index" do
          resource = create_test_resource(model_class)
          resource_id = resource.id

          assert_difference("#{model_class.name}.count", -1) do
            delete_with_auth send("admin_#{model_class.name.underscore}_path", resource)
          end

          assert_redirect_to_admin_index(model_class)
          refute model_class.exists?(resource_id)
        end

        should "not allow access without auth" do
          resource = create_test_resource(model_class)
          delete send("admin_#{model_class.name.underscore}_path", resource)

          assert_response :unauthorized
          assert model_class.exists?(resource.id)
        end
      end
    end
  end

  class_methods do
    def admin_crud_tests(model_class, index_columns: [], show_fields: [], form_fields: [], valid_create_attrs: {}, invalid_create_attrs: {}, update_attrs: {})
      include AdminCrudExamples::SharedExamples

      admin_index_page(model_class, index_columns: index_columns)
      admin_show_page(model_class, show_fields: show_fields)
      admin_new_page(model_class, form_fields: form_fields)
      admin_create(model_class, valid_attributes: valid_create_attrs, invalid_attributes: invalid_create_attrs)
      admin_edit_page(model_class, form_fields: form_fields)
      admin_update(model_class, update_attributes: update_attrs)
      admin_destroy(model_class)
    end
  end
end
