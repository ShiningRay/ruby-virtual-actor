require 'singleton'
require 'connection_pool'
require 'redis'
require 'msgpack'
require_relative 'logging'

module VirtualActor
  class Persistence
    include Singleton
    include Logging

    def initialize
      @redis = ConnectionPool.new(size: 5, timeout: 5) { Redis.new(url: Configuration.instance.redis_url) }
    end

    def save_actor_state(actor_id, state)
      @redis.with do |redis|
        redis.set("actor:#{actor_id}:state", MessagePack.pack(state))
        logger.debug "Saved state for actor #{actor_id}: #{state}"
      end
    end

    def load_actor_state(actor_id)
      @redis.with do |redis|
        if data = redis.get("actor:#{actor_id}:state")
          state = MessagePack.unpack(data)
          logger.debug "Loaded state for actor #{actor_id}: #{state}"
          state
        end
      end
    end
  end
end
