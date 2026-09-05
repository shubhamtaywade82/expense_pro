module Brokers
  class Registry
    ADAPTERS = {
      "dhanhq"         => Brokers::DhanHQAdapter,
      "coindcx"        => Brokers::CoinDCXAdapter,
      "delta_exchange" => Brokers::DeltaExchangeAdapter,
      "wazirx"         => Brokers::WazirXAdapter,
      "zerodha"        => Brokers::ZerodhaAdapter
    }.freeze

    class << self
      def for(broker_key)
        ADAPTERS[broker_key.to_s] || raise(UnknownBroker, "No adapter registered for broker: #{broker_key}")
      end
      alias_method :adapter_for, :for

      def build(broker_type, credential)
        adapter_for(broker_type).new(credential)
      end

      def registered_keys
        ADAPTERS.keys
      end

      def registered_names
        ADAPTERS.transform_values(&:display_name)
      end

      def available_brokers
        ADAPTERS.map do |key, adapter|
          {
            type: key,
            name: adapter.display_name,
            asset_classes: adapter.asset_classes,
            auth_type: adapter.auth_type,
            required_credentials: adapter.required_credentials,
            documentation_url: adapter.documentation_url
          }
        end
      end

      def crypto_brokers
        ADAPTERS.select { |_, a| a.asset_classes.include?(:crypto) }
      end

      def equity_brokers
        ADAPTERS.select { |_, a| a.asset_classes.include?(:equity) }
      end

      def register_all!
        # Kept as no-op for compatibility
      end
    end
  end
end
