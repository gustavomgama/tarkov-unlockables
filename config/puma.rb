# frozen_string_literal: true

# Puma Configuration

# Workers: number of processes. Puma is meant to run either in single mode
# (workers 0) or in cluster mode with 2+. A single forked worker is warned
# about and buys nothing: no copy-on-write saving and doubled memory. The
# Render starter instance sets WEB_CONCURRENCY=1, so treat 1 as single mode.
# The count must be set explicitly: Puma 8 already defaults workers from
# WEB_CONCURRENCY, so simply not calling `workers` would still fork one.
# In test the app is booted single-mode (Capybara's Puma server ignores the
# worker count), so default to 1 there — otherwise the cluster-only fork hooks
# below are registered and Puma warns that they will never run.
default_workers = ENV["RAILS_ENV"] == "test" ? 1 : 2
workers_count = Integer(ENV.fetch("WEB_CONCURRENCY") { default_workers })
workers(workers_count > 1 ? workers_count : 0)

# Threads: per-worker thread pool (default: 5)
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# Port configuration
port ENV.fetch("PORT") { 3000 }

# Environment
environment ENV.fetch("RAILS_ENV") { "development" }

# PID file
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Restart plugin for zero-downtime deployments
plugin :tmp_restart

# Solid Queue supervisor (if using)
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

# Preloading and the fork hooks only apply in cluster mode.
if workers_count > 1
  # Preload application for Copy-on-Write (CoW) memory savings
  preload_app!

  before_fork do
    # Disconnect DB before fork to avoid sharing connections across processes
    ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
  end

  before_worker_boot do
    # Re-establish DB connections after fork
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
  end
end

# Production optimizations
if ENV["RAILS_ENV"] == "production"
  # Worker timeout
  worker_timeout 60

  # Queue requests when all workers busy
  queue_requests true
end
