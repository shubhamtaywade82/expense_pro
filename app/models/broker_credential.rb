class BrokerCredential < ApplicationRecord
  belongs_to :user
  # has_many :broker_sync_logs, dependent: :destroy

  # ── Broker Types ──
  enum :broker_type, {
    dhanhq:         "dhanhq",
    coindcx:        "coindcx",
    delta_exchange: "delta_exchange",
    wazirx:         "wazirx",
    coinswitch:     "coinswitch",
    zerodha:        "zerodha",
    groww:          "groww",
    upstox:         "upstox",
    angel_one:      "angel_one"
  }

  enum :status, { active: 0, expired: 1, revoked: 2, error: 3 }, default: :active

  # ── Encrypted Storage ──
  # NEVER store raw API secrets in plain jsonb
  # Use Rails 8 encrypted attributes:
  encrypts :api_key
  encrypts :api_secret
  encrypts :access_token
  encrypts :refresh_token
  encrypts :passphrase          # some brokers need this

  # Non-sensitive config in jsonb:
  # { base_url:, environment: "production"/"sandbox", account_id:, sub_account: }
  # Already has config jsonb column

  validates :broker_type, presence: true
  validates :broker_type, uniqueness: { scope: :user_id },
            unless: :allows_multiple_accounts?

  # ── Credential Validation ──

  validate :required_credentials_present

  def adapter
    Brokers::Registry.build(broker_type, self)
  end

  def authenticate!
    result = adapter.authenticate!
    update!(status: :active, last_authenticated_at: Time.current)
    result
  rescue Brokers::BrokerError => e
    update!(status: :error)
    raise
  end

  def refresh_token!
    return unless adapter.class.auth_type == :oauth2
    new_tokens = adapter.refresh_token!
    update!(
      access_token: new_tokens[:access_token],
      refresh_token: new_tokens[:refresh_token],
      token_expires_at: new_tokens[:expires_at]
    )
  end

  def token_expired?
    return false unless token_expires_at
    token_expires_at < Time.current
  end

  def ensure_valid_token!
    refresh_token! if token_expired?
  end

  # ── Safe Serialization (never expose secrets) ──

  def safe_attributes
    {
      id: id,
      broker_type: broker_type,
      display_name: adapter.class.display_name,
      status: status,
      has_api_key: api_key.present?,
      has_api_secret: api_secret.present?,
      has_access_token: access_token.present?,
      token_expires_at: token_expires_at,
      config: safe_config,
      last_authenticated_at: last_authenticated_at,
      last_sync_at: last_sync_at,
      created_at: created_at
    }
  end

  private

  def required_credentials_present
    required = adapter.class.required_credentials
    required.each do |field|
      errors.add(field, "is required for #{broker_type}") if send(field).blank?
    end
  rescue Brokers::UnknownBroker
    errors.add(:broker_type, "is not a supported broker")
  end

  def allows_multiple_accounts?
    # Some users may have multiple Zerodha accounts, etc.
    config&.dig("allow_multiple") == true
  end

  def safe_config
    (config || {}).except("api_secret", "passphrase", "private_key")
  end
end
