require_relative 'registry'

module VirtualActor
  class Proxy
    def initialize(actor_id, actor_class)
      @actor_id = actor_id
      @actor_class = actor_class
      @actor = Registry.instance.create_or_get_actor(@actor_id, @actor_class)
    end

    def method_missing(method_name, *args)
      unless @actor.class.exposed_methods.include?(method_name.to_sym)
        super
      end

      @actor.send_message(method: method_name, args: args)
    end

    def respond_to_missing?(method_name, include_private = false)
      @actor.class.exposed_methods.include?(method_name.to_sym) || super
    end

    def inspect
      "#<#{self.class.name}:0x#{object_id.to_s(16)} actor_id=#{@actor_id} actor_class=#{@actor_class}>"
    end
  end
end
