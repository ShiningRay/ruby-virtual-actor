require 'redis'
require 'connection_pool'
require 'msgpack'

module VirtualActor
  class Persistence
    include Singleton
    include Logging

    def initialize
      @redis = ConnectionPool.new(size: 5, timeout: 5) do
        Redis.new(url: Configuration.instance.redis_url)
      end
    end

    def save_actor_state(actor_id, state)
      return unless Configuration.instance.persistence_enabled

      @redis.with do |conn|
        begin
          serialized_state = MessagePack.pack(state)
          conn.set("actor:#{actor_id}:state", serialized_state)
          logger.debug "Saved state for actor #{actor_id}"
        rescue => e
          logger.error "Failed to save state for actor #{actor_id}: #{e.message}"
          raise
        end
      end
    end

    def load_actor_state(actor_id)
      return unless Configuration.instance.persistence_enabled

      @redis.with do |conn|
        begin
          serialized_state = conn.get("actor:#{actor_id}:state")
          return nil unless serialized_state

          state = MessagePack.unpack(serialized_state)
          logger.debug "Loaded state for actor #{actor_id}"
          state
        rescue => e
          logger.error "Failed to load state for actor #{actor_id}: #{e.message}"
          raise
        end
      end
    end

    def delete_actor_state(actor_id)
      return unless Configuration.instance.persistence_enabled

      @redis.with do |conn|
        begin
          conn.del("actor:#{actor_id}:state")
          logger.debug "Deleted state for actor #{actor_id}"
        rescue => e
          logger.error "Failed to delete state for actor #{actor_id}: #{e.message}"
          raise
        end
      end
    end
  end
end
