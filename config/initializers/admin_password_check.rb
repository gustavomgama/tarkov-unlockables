# frozen_string_literal: true

# Security: the admin panel must never run without an explicit password.
# Fail hard at boot in production rather than serving an open admin panel.
if Rails.env.production? && ENV["ADMIN_PASSWORD"].blank?
  raise ArgumentError,
        "ADMIN_PASSWORD must be set in production — refusing to boot an open admin panel"
end
