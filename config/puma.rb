# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.
#
# Puma starts a configurable number of processes (workers) and each process
# serves each request in a thread from an internal thread pool.
#
# Concurrency env vars (set in Once → Settings → Environment):
#   WEB_CONCURRENCY     — Puma worker processes (default 1). Use 2+ with preload_app!.
#   RAILS_MAX_THREADS   — Threads per Puma worker (default 3).
#   SOLID_QUEUE_IN_PUMA — Set to "false" to disable the Solid Queue Puma plugin.
#
# See docs/self-hosting.md and config/queue.yml for Solid Queue worker settings.

max_threads = Integer(ENV.fetch("RAILS_MAX_THREADS", 3))
threads max_threads, max_threads

workers_count = Integer(ENV.fetch("WEB_CONCURRENCY", 1))
if workers_count > 1
  workers workers_count
  preload_app!
end

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3000)

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Run the Solid Queue supervisor inside of Puma for single-server deployments.
# Requires preload_app! when WEB_CONCURRENCY > 1. See solid_queue Puma plugin docs.
plugin :solid_queue unless ENV["SOLID_QUEUE_IN_PUMA"] == "false"

plugin :tailwindcss if ENV.fetch("RAILS_ENV", "development") == "development"

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
