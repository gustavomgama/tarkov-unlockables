# Be sure to restart your server when you modify this file.

# Content Security Policy for the public site.
#
# Deliberately nonce-free. The app serves some pages through `fresh_when(...,
# public: true)` (tasks), so a per-request nonce would be cached in the response
# body while the header changes on every revalidation — the stale nonce would be
# rejected and the inline importmap would stop loading. A session-id nonce (the
# other common recipe) would leak the session id through those same public
# caches. `'unsafe-inline'` is the price of that caching; the host allowlists
# still block injected external scripts, and object/base/frame-ancestors are
# locked down. Revisit once those pages stop being publicly cacheable.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.base_uri        :self
    policy.object_src      :none
    policy.frame_ancestors :none
    policy.form_action     :self

    # Google Fonts CSS, plus the Bender woff2 files preloaded from tarkov.dev.
    policy.style_src :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.font_src  :self, :data, "https://fonts.gstatic.com", "https://tarkov.dev"
    # Item art comes from arbitrary https hosts in the imported data.
    policy.img_src   :self, :data, :https

    # Inline importmap + module tags, plus the two footer embeds.
    policy.script_src  :self, :unsafe_inline, "https://tally.so", "https://utteranc.es"
    policy.connect_src :self, "https://tally.so"
    policy.frame_src   "https://tally.so", "https://github.com", "https://utteranc.es"
  end
end
