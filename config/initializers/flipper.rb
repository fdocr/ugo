Rails.application.config.after_initialize do
  Flipper.add(:open_sourced) unless Flipper.exist?(:open_sourced)
  Flipper.add(:open_beta) unless Flipper.exist?(:open_beta)
rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
  # Tables haven't been created yet — safe to skip during migrations / db:create.
end
