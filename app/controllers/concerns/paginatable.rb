module Paginatable
  extend ActiveSupport::Concern

  private

  def paginate(scope)
    per_page = (params[:per_page] || 25).to_i
    per_page = [per_page, 100].min
    page = [(params[:page] || 1).to_i, 1].max
    offset = (page - 1) * per_page

    @resources = scope.limit(per_page).offset(offset)
    @total_count = scope.count
    @current_page = page
    @per_page = per_page
    @total_pages = (@total_count.to_f / per_page).ceil
  end
end
