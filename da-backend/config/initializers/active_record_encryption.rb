Rails.application.config.active_record.encryption.primary_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY", "zUFdyLQ6ZLqenwGvbTBLdK1ItHSN4SOf")
Rails.application.config.active_record.encryption.deterministic_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY", "m9seoDYSvbwbv345W4zxg03c8TyiOIkA")
Rails.application.config.active_record.encryption.key_derivation_salt = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT", "m7yMqOyG21MAJTrYhVgFoFahxroPhODK")
