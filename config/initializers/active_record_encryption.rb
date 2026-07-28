# frozen_string_literal: true

# Keys for `encrypts` (used by DhanCredential to store broker secrets at rest).
# Generate your own with: ruby -rsecurerandom -e '3.times { puts SecureRandom.alphanumeric(32) }'
Rails.application.config.active_record.encryption.primary_key = ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY", nil)
Rails.application.config.active_record.encryption.deterministic_key = ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY", nil)
Rails.application.config.active_record.encryption.key_derivation_salt = ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT", nil)
