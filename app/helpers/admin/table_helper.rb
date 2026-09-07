module Admin::TableHelper
  def admin_table(columns, resources)
    render(partial: "admin/shared/table", locals: { columns: columns, resources: resources })
  end
end
