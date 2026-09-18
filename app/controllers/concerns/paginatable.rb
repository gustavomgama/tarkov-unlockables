module Paginatable
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  private

  def paginate(scope)
    # `per_page` is user input. Trusting `.to_i` turned "abc"/"" into 0, which
    # made `(count / 0.0).ceil` raise FloatDomainError, and let a negative value
    # reach `limit(-1)`: every admin index 500d on `?per_page=abc` or `?per_page=0`.
    # Anything not a positive number is read as "use the default".
    requested = int_param(:per_page)
    @per_page = requested.positive? ? [ requested, MAX_PER_PAGE ].min : DEFAULT_PER_PAGE
    @current_page = [ int_param(:page), 1 ].max

    @resources = scope.limit(@per_page).offset((@current_page - 1) * @per_page)
    @total_count = scope.count
    @total_pages = (@total_count.to_f / @per_page).ceil
  end
end
