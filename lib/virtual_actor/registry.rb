require 'singleton'
require 'concurrent'
require_relative 'logging'
require_relative 'metrics'

module VirtualActor
  class Registry
    include Singleton
    include Logging

    def initialize
      @actors = Concurrent::Map.new
      @mutex = Mutex.new
      @grpc_clients = Concurrent::Map.new
    end

    def register(actor_id, actor)
      @actors[actor_id] = actor
      logger.info "Registered actor #{actor_id} of type #{actor.class.name}"
      update_metrics(actor.class.name)
    end

    def unregister(actor_id)
      if actor = @actors.delete(actor_id)
        logger.info "Unregistered actor #{actor_id} of type #{actor.class.name}"
        update_metrics(actor.class.name)
      end
    end

    def get_actor(actor_id)
      @actors[actor_id]
    end

    def actor_exists?(actor_id)
      @actors.key?(actor_id)
    end

    def create_or_get_actor(actor_id, actor_class, *args)
      @mutex.synchronize do
        unless actor_exists?(actor_id)
          # 检查其他节点是否有此Actor
          if state = find_actor_on_other_nodes(actor_id)
            actor = actor_class.new(actor_id, *args)
            actor.set_state(state)
            register(actor_id, actor)
          else
            actor = actor_class.new(actor_id, *args)
            register(actor_id, actor)
          end
        end
        get_actor(actor_id)
      end
    end

    def count_actors_of_type(actor_class)
      @actors.values.count { |actor| actor.is_a?(actor_class) }
    end

    private

    def find_actor_on_other_nodes(actor_id)
      Configuration.instance.cluster_nodes.each do |node|
        next if node == Configuration.instance.node_id

        begin
          client = get_grpc_client(node)
          response = client.get_actor_state(
            VirtualActor::ActorStateRequest.new(actor_id: actor_id)
          )
          
          if response.exists
            logger.info "Found actor #{actor_id} on node #{response.node_id}"
            return MessagePack.unpack(response.state)
          end
        rescue => e
          logger.error "Error contacting node #{node}: #{e.message}"
        end
      end
      nil
    end

    def get_grpc_client(node)
      @grpc_clients[node] ||= begin
        stub = VirtualActor::ActorService::Stub.new(
          node,
          :this_channel_is_insecure,
          timeout: 5
        )
        logger.info "Created gRPC client for node #{node}"
        stub
      end
    end

    def update_metrics(actor_type)
      Metrics.instance.set_actor_count(actor_type, count_actors_of_type(Object.const_get(actor_type)))
    end
  end
end
