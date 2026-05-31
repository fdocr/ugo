Rails.application.config.after_initialize do
  Flipper.add(:open_sourced) unless Flipper.exist?(:open_sourced)
rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
  # Tables haven't been created yet — safe to skip during migrations / db:create.
end
