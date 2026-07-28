# frozen_string_literal: true

# Per-user Dhan broker connection settings, configured from the Dhan Settings UI.
# Encrypted at rest; secrets are never re-serialized back to the frontend.
class DhanCredential < ApplicationRecord
  belongs_to :user

  encrypts :client_id
  encrypts :token_service_secret
  encrypts :fallback_access_token
end
