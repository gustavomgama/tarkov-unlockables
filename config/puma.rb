# frozen_string_literal: true

# Puma Configuration

# Workers: number of processes (default: 2 for 1-2GB RAM)
# Set WEB_CONCURRENCY=2 on the host for production
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# Threads: per-worker thread pool (default: 5)
# Set RAILS_MAX_THREADS=5 on the host for production
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# Preload application for Copy-on-Write (CoW) memory savings
preload_app!

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

# PID file configuration
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

# Connection handling
# Allow Puma to handle graceful shutdown
before_worker_boot do
  # Re-establish DB connections after fork
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

before_fork do
  # Disconnect DB before fork to avoid connection issues
  ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
end

# Production optimizations
if ENV["RAILS_ENV"] == "production"
  # Worker timeout
  worker_timeout 60

  # Queue requests when all workers busy
  queue_requests true
end
