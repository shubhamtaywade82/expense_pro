# frozen_string_literal: true

# Per-user, per-broker connection settings (Dhan, CoinDCX, Delta Exchange
# India, ...), configured from the broker's Settings UI. Encrypted at rest;
# secrets are never re-serialized back to the frontend.
class BrokerCredential < ApplicationRecord
  belongs_to :user

  encrypts :client_id
  encrypts :token_service_secret
  encrypts :fallback_access_token
end
