# frozen_string_literal: true

# Request-scoped current user, set by Api::V1::BaseController. Read by
# DhanHQ's access_token_provider (config/initializers/dhanhq.rb), which has
# no other way to know which user's broker credentials to use.
class Current < ActiveSupport::CurrentAttributes
  attribute :user
end
