# frozen_string_literal: true

# Never let a remote DATABASE_URL hijack development/test. Rails gives
# ENV["DATABASE_URL"] (and PRIMARY_DATABASE_URL) precedence over database.yml
# in every environment, so one exported Neon URL turns `rails db:reset` into
# a production wipe. Localhost URLs (CI) and unset vars pass through.
if !Rails.env.production?
  %w[DATABASE_URL PRIMARY_DATABASE_URL].each do |key|
    url = ENV[key]
    next if url.blank?

    host = begin
      URI.parse(url).host
    rescue URI::InvalidURIError
      nil
    end
    next if host.blank? || %w[localhost 127.0.0.1 ::1 db].include?(host)

    abort "Refusing to boot #{Rails.env} against remote DB #{host} from #{key}. " \
          "Unset it — Neon URLs belong in .env.production.local (loaded only in production)."
  end
end
