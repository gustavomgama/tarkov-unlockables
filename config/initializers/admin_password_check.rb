# frozen_string_literal: true

# Security: the admin panel must never run without an explicit password.
# Fail hard at boot in production rather than serving an open admin panel.
# SECRET_KEY_BASE_DUMMY marks the asset-precompile build step, which never
# serves requests — the real server boot still enforces the check.
if Rails.env.production? && ENV["ADMIN_PASSWORD"].blank? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
  raise ArgumentError,
        "ADMIN_PASSWORD must be set in production — refusing to boot an open admin panel"
end
