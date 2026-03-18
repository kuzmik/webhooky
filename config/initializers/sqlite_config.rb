Rails.application.configure do
  config.after_initialize do
    ActiveRecord::Base.connection.execute("PRAGMA journal_mode=WAL")
    ActiveRecord::Base.connection.execute("PRAGMA busy_timeout=5000")
  end
end
