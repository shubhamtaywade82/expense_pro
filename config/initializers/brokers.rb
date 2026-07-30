# frozen_string_literal: true

Rails.application.reloader.to_prepare do
  Brokers::Registry.register_all!
end