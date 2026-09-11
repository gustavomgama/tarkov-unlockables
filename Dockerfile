# syntax=docker/dockerfile:1
# Multi-stage build for Kamal deployment. Ruby 4.0.6, PostgreSQL.
FROM ruby:4.0.6-slim AS base

WORKDIR /rails
ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=1

# Runtime-only deps (kept in final image)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libpq5 libjemalloc2 libvips42 curl && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# ── Build stage: compilers + gems + assets ──────────────────────────
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install && rm -rf ~/.bundle "${BUNDLE_PATH}"/ruby/*/cache

COPY . .

# Precompile bootsnap + assets. Propshaft needs no secret at build time.
RUN SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile && \
    bundle exec bootsnap precompile --gemfile app/ lib/ && \
    rm -rf log tmp/storage

# ── Final stage: runtime only, non-root ─────────────────────────────
FROM base AS final

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=rails:rails /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p log storage tmp tmp/pids && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
