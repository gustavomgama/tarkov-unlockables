# Shared HTTP-basic auth for the admin integration tests: one place for the
# header and the get/post/patch/delete wrappers, so every admin test file does
# not redefine the same five methods.
module AdminRequestAuth
  extend ActiveSupport::Concern

  included do
    setup :set_admin_auth_headers
  end

  def set_admin_auth_headers
    @admin_password = ENV.fetch("ADMIN_PASSWORD") { "admin" }
    @admin_auth = {
      "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", @admin_password)
    }
  end

  def get_auth(url, **kwargs)
    get url, **kwargs.merge(headers: @admin_auth)
  end

  def post_auth(url, **kwargs)
    post url, **kwargs.merge(headers: @admin_auth)
  end

  def patch_auth(url, **kwargs)
    patch url, **kwargs.merge(headers: @admin_auth)
  end

  def delete_auth(url, **kwargs)
    delete url, **kwargs.merge(headers: @admin_auth)
  end
end
