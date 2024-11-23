module VirtualActor
  class Proxy
    def initialize(actor_id, actor_class)
      @actor_id = actor_id
      @actor_class = actor_class
    end

    def method_missing(method_name, *args, &block)
      actor = Registry.instance.create_or_get_actor(@actor_id, @actor_class)
      message = {
        method: method_name,
        args: args,
        block: block
      }
      actor.send_message(message)
    end

    def respond_to_missing?(method_name, include_private = false)
      true
    end
  end
end
