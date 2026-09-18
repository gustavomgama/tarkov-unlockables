require "test_helper"

# The catch-all rescue_from is the difference between a branded 500 page and a
# leaked exception. Both handlers are asserted directly: the render call is
# captured so the target, status and admin layout are pinned.
class ErrorHandlingTest < ActiveSupport::TestCase
  test "the public error handler renders the branded 500 page" do
    calls = capture_render(ApplicationController.new) { |controller| controller.send(:internal_server_error) }

    assert_equal [ "errors/internal_server_error" ], calls[:args]
    assert_equal :internal_server_error, calls[:options][:status]
    assert_nil calls[:options][:layout]
  end

  test "the admin error handler renders the 500 page in the admin layout" do
    calls = capture_render(Admin::ApplicationController.new) { |controller| controller.send(:internal_server_error) }

    assert_equal [ "errors/internal_server_error" ], calls[:args]
    assert_equal :internal_server_error, calls[:options][:status]
    assert_equal "admin/layouts/application", calls[:options][:layout]
  end

  private

  def capture_render(controller)
    captured = {}
    controller.define_singleton_method(:render) do |*args, **options|
      captured[:args] = args
      captured[:options] = options
    end

    yield controller
    captured
  end
end
