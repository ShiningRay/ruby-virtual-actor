require_relative '../lib/virtual_actor/base_actor'
require_relative '../lib/virtual_actor/registry'
require_relative '../lib/virtual_actor/proxy'
require_relative '../lib/virtual_actor/configuration'
require_relative 'counter_actor'

# 配置客户端
VirtualActor::Configuration.configure do |config|
  config.node_id = 'client-1'
  config.cluster_nodes = [
    'localhost:50051',
    'localhost:50052',
    'localhost:50053'
  ]
end

# 创建Actor代理
counter = VirtualActor::Proxy.new('distributed_counter', CounterActor)

# 执行一些操作
puts "Testing distributed counter..."

5.times do |i|
  puts "\nIteration #{i + 1}:"
  
  # 增加计数
  result = counter.increment
  puts "Incremented counter, new value: #{result}"
  
  # 获取当前值
  current = counter.get_count
  puts "Current count: #{current}"
  
  sleep 1
end

puts "\nTest completed!"
