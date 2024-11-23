require 'singleton'
require 'yaml'

module VirtualActor
  class Configuration
    include Singleton

    attr_accessor :redis_url, :grpc_port, :node_id, :cluster_nodes
    attr_accessor :metrics_port, :log_level, :persistence_enabled

    def initialize
      @redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/0'
      @grpc_port = (ENV['GRPC_PORT'] || 50051).to_i
      @node_id = ENV['NODE_ID'] || generate_node_id
      @cluster_nodes = []
      @metrics_port = (ENV['METRICS_PORT'] || 9090).to_i
      @log_level = ENV['LOG_LEVEL'] || 'info'
      @persistence_enabled = ENV['PERSISTENCE_ENABLED'] != 'false'
    end

    def self.configure
      yield instance if block_given?
    end

    private

    def generate_node_id
      "node-#{SecureRandom.uuid[0..7]}"
    end
  end
end
