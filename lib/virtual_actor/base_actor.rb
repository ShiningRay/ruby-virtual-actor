require 'concurrent'
require 'msgpack'
require_relative 'logging'
require_relative 'metrics'
require_relative 'persistence'

module VirtualActor
  class BaseActor
    include Logging

    def initialize(actor_id)
      @actor_id = actor_id
      @mailbox = Concurrent::Array.new
      @mutex = Mutex.new
      @condition = ConditionVariable.new
      
      # 尝试恢复状态
      restore_state
      
      # 启动消息循环
      start_message_loop
      
      # 更新指标
      update_metrics
    end

    def send_message(message)
      start_time = Time.now
      
      @mutex.synchronize do
        @mailbox << message
        @condition.signal
      end

      # 记录消息处理时间
      duration = Time.now - start_time
      Metrics.instance.observe_message_duration(
        self.class.name,
        message[:method].to_s,
        duration
      )
      
      # 增加消息计数
      Metrics.instance.increment_message_counter(
        self.class.name,
        message[:method].to_s
      )
    end

    def save_state
      state = get_state
      Persistence.instance.save_actor_state(@actor_id, state) if state
    end

    protected

    def get_state
      nil
    end

    def restore_state
      state = Persistence.instance.load_actor_state(@actor_id)
      set_state(state) if state
    end

    def set_state(state)
      # 子类重写此方法以恢复状态
    end

    private

    def start_message_loop
      Thread.new do
        loop do
          message = nil
          @mutex.synchronize do
            while @mailbox.empty?
              @condition.wait(@mutex)
            end
            message = @mailbox.shift
          end
          
          begin
            handle_message(message) if message
            # 处理完消息后保存状态
            save_state
          rescue => e
            logger.error "Error processing message: #{e.message}\n#{e.backtrace.join("\n")}"
          end
        end
      end
    end

    def handle_message(message)
      raise NotImplementedError, "#{self.class} needs to implement 'handle_message'"
    end

    def update_metrics
      Metrics.instance.set_actor_count(self.class.name, Registry.instance.count_actors_of_type(self.class))
    end
  end
end
