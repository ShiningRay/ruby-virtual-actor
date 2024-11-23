require 'prometheus/client'
require 'prometheus/client/push'
require 'singleton'

module VirtualActor
  class Metrics
    include Singleton

    attr_reader :registry

    def initialize
      @registry = Prometheus::Client.registry

      # 定义指标
      @message_counter = @registry.counter(
        :virtual_actor_messages_total,
        docstring: 'Total number of messages processed by actors',
        labels: [:actor_type, :message_type]
      )

      @message_duration = @registry.histogram(
        :virtual_actor_message_duration_seconds,
        docstring: 'Time spent processing messages',
        labels: [:actor_type, :message_type]
      )

      @actor_count = @registry.gauge(
        :virtual_actor_instances,
        docstring: 'Number of actor instances',
        labels: [:actor_type]
      )
    end

    def increment_message_counter(actor_type, message_type)
      @message_counter.increment(labels: { actor_type: actor_type, message_type: message_type })
    end

    def observe_message_duration(actor_type, message_type, duration)
      @message_duration.observe(duration, labels: { actor_type: actor_type, message_type: message_type })
    end

    def set_actor_count(actor_type, count)
      @actor_count.set(count, labels: { actor_type: actor_type })
    end

    def start_server
      require 'webrick'
      Thread.new do
        server = WEBrick::HTTPServer.new(
          Port: Configuration.instance.metrics_port,
          Logger: WEBrick::Log.new("/dev/null"),
          AccessLog: []
        )

        server.mount_proc '/metrics' do |_, response|
          response.status = 200
          response['Content-Type'] = 'text/plain'
          response.body = Prometheus::Client::Formats::Text.marshal(@registry)
        end

        server.start
      end
    end
  end
end
