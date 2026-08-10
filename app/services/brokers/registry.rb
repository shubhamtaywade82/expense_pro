module Brokers
  class Registry
    class AdapterNotRegisteredError < StandardError; end
    class UnknownBrokerError < StandardError; end
    
    class << self
      def register(adapter_class)
        # Store the class, not an instance - prevents shared state issues
        adapter_key = adapter_class.broker_type
        adapters[adapter_key] = adapter_class
      end

      def for(broker_key)
        adapter_class = adapters[broker_key.to_s]
        raise AdapterNotRegisteredError, "No adapter registered for broker: #{broker_key}" unless adapter_class
        adapter_class
      end

      # Returns the adapter class for the given broker type
      def adapter_for(broker_type)
        for(broker_type)
      end

      # Builds a new adapter instance with the given credential
      def build(broker_type, credential)
        adapter_class = adapter_for(broker_type)
        adapter_class.new(credential)
      end

      def registered_keys
        adapters.keys
      end

      def registered_names
        adapters.transform_values(&:display_name)
      end

      # Returns all registered brokers with their metadata
      def available_brokers
        adapters.map do |key, adapter_class|
          {
            key: key,
            name: adapter_class.display_name,
            asset_classes: adapter_class.asset_classes,
            auth_type: adapter_class.auth_type,
            required_credentials: adapter_class.required_credentials,
            documentation_url: adapter_class.documentation_url
          }
        end
      end

      # Returns crypto brokers
      def crypto_brokers
        adapters.select { |_, adapter_class| adapter_class.asset_classes.include?(:crypto) }
      end

      # Returns equity brokers
      def equity_brokers
        adapters.select { |_, adapter_class| adapter_class.asset_classes.include?(:equity) }
      end

      def register_all!
        register(Brokers::DhanHQAdapter)
        register(Brokers::CoinDCXAdapter)
        register(Brokers::DeltaExchangeAdapter)
        register(Brokers::WazirXAdapter)
        register(Brokers::ZerodhaAdapter)
      end

      private

      def adapters
        @adapters ||= {}
      end
    end
  end
end
