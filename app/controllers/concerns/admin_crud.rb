module AdminCrud
  extend ActiveSupport::Concern
  include Paginatable

  class_methods do
    def crud_actions(model:)
      @resource_class = model
    end

    def resource_class
      @resource_class
    end

    def searchable_columns(*columns)
      @searchable_columns = columns
    end

    def search_columns
      @searchable_columns || []
    end
  end

  included do
    before_action :set_resource, only: [ :show, :edit, :update, :destroy ]
  end

  def index
    scope = resource_class.all.order(id: :desc)
    # loose_search_param is a no-op when the query is blank or the resource
    # declares no searchable columns (see LooseSearchable#loose_search).
    scope = loose_search_param(scope, self.class.search_columns)
    paginate(scope)
  end

  def show
  end

  def new
    @resource = resource_class.new
  end

  def create
    @resource = resource_class.new(resource_params)
    if @resource.save
      redirect_to admin_resource_path(@resource), notice: "#{resource_class.name} created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @resource.update(resource_params)
      redirect_to admin_resource_path(@resource), notice: "#{resource_class.name} updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @resource.destroy
    redirect_to [ :admin, resource_class ], notice: "#{resource_class.name} deleted"
  end

  private

  # The controller's resource class, read once per call site instead of
  # repeating `self.class.resource_class` (reek's DuplicateMethodCall).
  def resource_class
    self.class.resource_class
  end

  # Resolves the admin show path for a resource using the controller's base
  # resource class, so STI subclasses (e.g. Item::Generic) don't generate
  # non-existent polymorphic routes like admin_item_generic_path.
  def admin_resource_path(resource)
    send("admin_#{resource_class.name.underscore}_path", resource)
  end

  def set_resource
    @resource = resource_class.find(params[:id])
  end

  def resource_params
    raise NotImplementedError, "Subclasses must define resource_params"
  end
end
