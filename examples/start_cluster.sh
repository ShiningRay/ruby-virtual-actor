#!/bin/bash

# 确保Redis正在运行
redis-cli ping > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Starting Redis..."
    brew services start redis
    sleep 2
fi

# 创建日志目录
mkdir -p log

# 启动三个节点
ruby cluster_example.rb node-1 50051 9091 &
echo "Started node-1"
sleep 2

ruby cluster_example.rb node-2 50052 9092 &
echo "Started node-2"
sleep 2

ruby cluster_example.rb node-3 50053 9093 &
echo "Started node-3"

echo "Cluster started!"
echo "Node 1: gRPC on port 50051, metrics on port 9091"
echo "Node 2: gRPC on port 50052, metrics on port 9092"
echo "Node 3: gRPC on port 50053, metrics on port 9093"
echo
echo "Press Ctrl+C to stop all nodes"

# 等待用户中断
trap "pkill -f 'ruby cluster_example.rb'; echo 'Stopping all nodes...'" INT
wait
