module Brokers
  class Registry
    class AdapterNotRegisteredError < StandardError; end

    class << self
      def register(adapter)
        adapters[adapter.broker_key] = adapter
      end

      def for(broker_key)
        adapter = adapters[broker_key]
        raise AdapterNotRegisteredError, "No adapter registered for broker: #{broker_key}" unless adapter
        adapter
      end

      def registered_keys
        adapters.keys
      end

      def registered_names
        adapters.transform_values(&:broker_name)
      end

      def register_all!
        register(Brokers::DhanHQAdapter.new)
        register(Brokers::CoinDCXAdapter.new)
        register(Brokers::DeltaExchangeAdapter.new)
      end

      private

      def adapters
        @adapters ||= {}
      end
    end
  end
end
