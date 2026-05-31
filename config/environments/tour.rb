require "active_support/core_ext/integer/time"

# Dedicated environment for `bin/ui-tour`. It mirrors development closely
# (eager_load=false, full error pages so failures are obvious in screenshots)
# but runs against an isolated SQLite database (see config/database.yml) and
# uses a quieter, deterministic configuration so screenshots stay stable.
Rails.application.configure do
  # Local UI tour only (isolated SQLite via bin/ui-tour; never deployed).
  # Avoids requiring tour-specific Rails credentials for secret_key_base.
  config.secret_key_base = "4ac181dd47dd6a2b855f4a94f2f397b301793ba62aadc97ae1098282cf1b1dcaa7671fd57f22778e8314bef1f203e61ee46545d41f456d149b2c06b04e5fbaeb"

  config.enable_reloading = false
  config.eager_load = false

  config.consider_all_requests_local = true
  config.server_timing = false

  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  config.active_storage.service = :local

  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false
  config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
  config.action_mailer.delivery_method = :test

  config.active_support.deprecation = :silence
  config.active_record.migration_error = false
  config.active_record.verbose_query_logs = false
  config.active_record.query_log_tags_enabled = false

  # Run jobs inline so any UI that reflects job side effects (e.g. visit counts)
  # shows up immediately in the captured screenshots.
  config.active_job.queue_adapter = :inline

  config.action_view.annotate_rendered_view_with_filenames = false
  config.action_controller.raise_on_missing_callback_actions = true

  config.hosts.clear
  config.log_level = :warn

  config.action_dispatch.show_exceptions = :rescuable
end
