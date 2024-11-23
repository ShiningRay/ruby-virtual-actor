require_relative 'logging'
require_relative 'persistence'
require_relative 'metrics'

module VirtualActor
  class BaseActor
    include Logging

    class << self
      def state(*attributes)
        @state_attributes ||= []
        @state_attributes.concat(attributes)
        attr_accessor(*attributes)
      end

      def expose(*methods)
        @exposed_methods ||= []
        @exposed_methods.concat(methods)
      end

      def init(&block)
        @init_block = block
      end

      def state_attributes
        @state_attributes ||= []
      end

      def exposed_methods
        @exposed_methods ||= []
      end

      def init_block
        @init_block
      end

      def get(actor_id)
        Proxy.new(actor_id, self)
      end
    end

    def initialize(actor_id)
      @actor_id = actor_id
      instance_eval(&self.class.init_block) if self.class.init_block
      restore_state
    end

    def send_message(method:, args: [])
      unless self.class.exposed_methods.include?(method.to_sym)
        logger.warn "Method #{method} is not exposed"
        return nil
      end

      result = send(method, *args)
      save_state
      result
    end

    private

    def save_state
      state = {}
      self.class.state_attributes.each do |attr|
        state[attr] = instance_variable_get("@#{attr}")
      end
      Persistence.instance.save_actor_state(@actor_id, state)
    end

    def restore_state
      if state = Persistence.instance.load_actor_state(@actor_id)
        state.each do |attr, value|
          instance_variable_set("@#{attr}", value)
        end
      end
    end
  end
end
