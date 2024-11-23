require_relative '../lib/virtual_actor/base_actor'
require_relative '../lib/virtual_actor/registry'
require_relative '../lib/virtual_actor/proxy'
require_relative '../lib/virtual_actor/metrics'
require_relative '../lib/virtual_actor/persistence'
require_relative '../lib/virtual_actor/logging'
require_relative '../lib/virtual_actor/configuration'
require_relative '../lib/virtual_actor/cluster_manager'
require_relative '../lib/virtual_actor/grpc_service'

class DistributedCounter < VirtualActor::BaseActor
  def initialize(actor_id)
    @count = 0
    super(actor_id)
  end

  private

  def handle_message(message)
    case message[:method]
    when :increment
      @count += 1
      logger.info "Counter incremented to #{@count}"
      @count
    when :decrement
      @count -= 1
      logger.info "Counter decremented to #{@count}"
      @count
    when :get_count
      logger.info "Current count: #{@count}"
      @count
    else
      logger.warn "Unknown message: #{message[:method]}"
      nil
    end
  end

  protected

  def get_state
    { count: @count }
  end

  def set_state(state)
    @count = state[:count]
  end
end

def start_node(node_id, grpc_port, metrics_port)
  # 配置节点
  VirtualActor::Configuration.configure do |config|
    config.redis_url = 'redis://localhost:6379/0'
    config.grpc_port = grpc_port
    config.metrics_port = metrics_port
    config.node_id = node_id
    config.log_level = 'info'
  end

  # 启动监控服务器
  VirtualActor::Metrics.instance.start_server

  # 启动gRPC服务器
  server = VirtualActor::GrpcServer.new
  Thread.new { server.start }

  # 启动集群管理器
  cluster_manager = VirtualActor::ClusterManager.instance
  cluster_manager.start

  # 返回清理函数
  -> {
    cluster_manager.stop
    server.stop
  }
end

# 根据命令行参数启动节点
node_id = ARGV[0] || "node-1"
grpc_port = (ARGV[1] || 50051).to_i
metrics_port = (ARGV[2] || 9090).to_i

cleanup = start_node(node_id, grpc_port, metrics_port)

puts "Node #{node_id} started:"
puts "- gRPC server running on port #{grpc_port}"
puts "- Metrics available at http://localhost:#{metrics_port}/metrics"
puts "Press Ctrl+C to exit"

# 如果是第一个节点，创建并使用Actor
if node_id == "node-1"
  sleep 2  # 等待服务器启动
  counter = VirtualActor::Proxy.new('distributed_counter', DistributedCounter)
  counter.increment
  counter.increment
  puts "Incremented counter twice on node 1"
end

# 保持进程运行
begin
  sleep
rescue Interrupt
  puts "\nShutting down..."
  cleanup.call
end
