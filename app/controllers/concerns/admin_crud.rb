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
    scope = self.class.resource_class.all.order(id: :desc)
    if params[:q].present? && self.class.search_columns.any?
      scope = scope.loose_search(params[:q], columns: self.class.search_columns.map(&:to_s))
    end
    paginate(scope)
  end

  def show
  end

  def new
    @resource = self.class.resource_class.new
  end

  def create
    @resource = self.class.resource_class.new(resource_params)
    if @resource.save
      redirect_to admin_resource_path(@resource), notice: "#{self.class.resource_class.name} created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @resource.update(resource_params)
      redirect_to admin_resource_path(@resource), notice: "#{self.class.resource_class.name} updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @resource.destroy
    redirect_to [ :admin, self.class.resource_class ], notice: "#{self.class.resource_class.name} deleted"
  end

  private

  # Resolves the admin show path for a resource using the controller's base
  # resource class, so STI subclasses (e.g. Item::Generic) don't generate
  # non-existent polymorphic routes like admin_item_generic_path.
  def admin_resource_path(resource)
    send("admin_#{self.class.resource_class.name.underscore}_path", resource)
  end

  def set_resource
    @resource = self.class.resource_class.find(params[:id])
  end

  def resource_params
    raise NotImplementedError, "Subclasses must define resource_params"
  end
end
