require_relative '../lib/virtual_actor/base_actor'
require_relative '../lib/virtual_actor/registry'
require_relative '../lib/virtual_actor/proxy'
require_relative '../lib/virtual_actor/metrics'
require_relative '../lib/virtual_actor/persistence'
require_relative '../lib/virtual_actor/logging'
require_relative '../lib/virtual_actor/configuration'

class CounterActor < VirtualActor::BaseActor
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

# 配置框架
VirtualActor::Configuration.configure do |config|
  config.redis_url = 'redis://localhost:6379/0'
  config.grpc_port = 50051
  config.metrics_port = 9090
  config.log_level = 'info'
end

# 启动监控服务器
VirtualActor::Metrics.instance.start_server

# 启动gRPC服务器
server = VirtualActor::GrpcServer.new
Thread.new { server.start }

# 使用示例
counter_proxy = VirtualActor::Proxy.new('counter1', CounterActor)
counter_proxy.increment
counter_proxy.increment
counter_proxy.get_count
counter_proxy.decrement
counter_proxy.get_count

puts "\nMetrics available at http://localhost:#{VirtualActor::Configuration.instance.metrics_port}/metrics"
puts "Press Ctrl+C to exit"

# 保持进程运行
begin
  sleep
rescue Interrupt
  puts "\nShutting down..."
  server.stop
end
