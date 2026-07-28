# frozen_string_literal: true

if defined?(Bullet) && (Rails.env.development? || Rails.env.test?)
  Rails.application.config.after_initialize do
    Bullet.enable = true
    Bullet.alert = false
    Bullet.bullet_logger = true
    Bullet.console = Rails.env.development?
    Bullet.rails_logger = true
    Bullet.add_footer = Rails.env.development?

    # In test, an N+1 fails the test outright instead of only logging —
    # that's what turns "detect" into "prevent regressions."
    Bullet.raise = Rails.env.test?
  end
end
