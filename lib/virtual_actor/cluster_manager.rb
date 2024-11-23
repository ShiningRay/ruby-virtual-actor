require 'redis'
require 'json'
require_relative 'logging'
require_relative 'configuration'

module VirtualActor
  class ClusterManager
    include Singleton
    include Logging

    CLUSTER_KEY = 'virtual_actor:cluster:nodes'
    HEARTBEAT_INTERVAL = 5  # 秒
    NODE_TIMEOUT = 15       # 秒

    def initialize
      @redis = Redis.new(url: Configuration.instance.redis_url)
      @node_id = Configuration.instance.node_id
      @running = false
    end

    def start
      return if @running

      @running = true
      register_node
      start_heartbeat
      start_node_monitor
      
      logger.info "Node #{@node_id} joined cluster"
      update_cluster_nodes
    end

    def stop
      return unless @running

      @running = false
      unregister_node
      logger.info "Node #{@node_id} left cluster"
    end

    def alive_nodes
      now = Time.now.to_i
      nodes = @redis.hgetall(CLUSTER_KEY)
      nodes.select { |_, last_seen| now - last_seen.to_i < NODE_TIMEOUT }
           .keys
    end

    private

    def register_node
      update_heartbeat
    end

    def unregister_node
      @redis.hdel(CLUSTER_KEY, @node_id)
    end

    def update_heartbeat
      @redis.hset(CLUSTER_KEY, @node_id, Time.now.to_i)
    end

    def start_heartbeat
      Thread.new do
        while @running
          begin
            update_heartbeat
            sleep HEARTBEAT_INTERVAL
          rescue => e
            logger.error "Heartbeat error: #{e.message}"
            sleep 1
          end
        end
      end
    end

    def start_node_monitor
      Thread.new do
        while @running
          begin
            update_cluster_nodes
            sleep HEARTBEAT_INTERVAL
          rescue => e
            logger.error "Node monitor error: #{e.message}"
            sleep 1
          end
        end
      end
    end

    def update_cluster_nodes
      nodes = alive_nodes
      old_nodes = Configuration.instance.cluster_nodes

      if nodes != old_nodes
        logger.info "Cluster nodes changed: #{nodes}"
        Configuration.instance.cluster_nodes = nodes
      end
    end
  end
end
