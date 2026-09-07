module Admin::ApplicationHelper
  def admin_nav_link(label, model)
    controller_name = model.name.underscore.pluralize
    is_active = params[:controller] == "admin/#{controller_name}"
    classes = "block px-3 py-2 rounded text-sm hover:bg-[var(--bg-surface)] hover:text-[var(--accent)] transition-colors"
    classes += " bg-[var(--bg-surface)] text-[var(--accent)]" if is_active
    link_to label, [ :admin, model ], class: classes
  end

  # Resolve admin paths via the resource's base class so STI subclasses
  # (e.g. Item::Generic) don't generate non-existent polymorphic routes.
  def admin_resource_path(resource)
    send("admin_#{resource.class.base_class.name.underscore}_path", resource)
  end

  def edit_admin_resource_path(resource)
    send("edit_admin_#{resource.class.base_class.name.underscore}_path", resource)
  end
end
