require "test_helper"

# AdminCrud is a shared concern: every admin controller must supply its own
# strong params. The base implementation is a guard, not a fallback.
class AdminCrudTest < ActiveSupport::TestCase
  test "resource_params raises until a controller implements it" do
    bare_controller = Class.new(ApplicationController) { include AdminCrud }

    error = assert_raises(NotImplementedError) { bare_controller.new.send(:resource_params) }
    assert_match(/Subclasses must define resource_params/, error.message)
  end
end
