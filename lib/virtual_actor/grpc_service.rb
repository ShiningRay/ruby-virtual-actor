require 'grpc'
require_relative 'virtual_actor_services_pb'

module VirtualActor
  class GrpcService < VirtualActor::ActorService::Service
    include Logging

    def send_message(request, _call)
      begin
        actor = Registry.instance.create_or_get_actor(
          request.actor_id,
          Object.const_get(request.actor_type)
        )

        args = MessagePack.unpack(request.serialized_args)
        result = actor.send_message({
          method: request.method_name.to_sym,
          args: args
        })

        VirtualActor::MessageResponse.new(
          success: true,
          result: MessagePack.pack(result)
        )
      rescue => e
        logger.error "Error processing message: #{e.message}"
        VirtualActor::MessageResponse.new(
          success: false,
          error_message: e.message
        )
      end
    end

    def get_actor_state(request, _call)
      begin
        state = Persistence.instance.load_actor_state(request.actor_id)
        if state
          VirtualActor::ActorStateResponse.new(
            exists: true,
            node_id: Configuration.instance.node_id,
            state: MessagePack.pack(state)
          )
        else
          VirtualActor::ActorStateResponse.new(
            exists: false
          )
        end
      rescue => e
        logger.error "Error getting actor state: #{e.message}"
        VirtualActor::ActorStateResponse.new(
          exists: false
        )
      end
    end
  end

  class GrpcServer
    include Logging

    def initialize
      @server = GRPC::RpcServer.new
      @server.add_http2_port(
        "0.0.0.0:#{Configuration.instance.grpc_port}",
        :this_port_is_insecure
      )
      @server.handle(GrpcService.new)
    end

    def start
      logger.info "Starting gRPC server on port #{Configuration.instance.grpc_port}"
      @server.run
    end

    def stop
      logger.info "Stopping gRPC server"
      @server.stop
    end
  end
end
