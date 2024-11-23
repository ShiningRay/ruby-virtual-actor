require 'logging'

module VirtualActor
  module Logging
    def self.included(base)
      base.extend(ClassMethods)
    end

    def logger
      @logger ||= self.class.logger
    end

    module ClassMethods
      def logger
        @logger ||= setup_logger
      end

      private

      def setup_logger
        logger = ::Logging.logger[self]
        logger.level = ::Logging.level_num(Configuration.instance.log_level)
        logger.add_appenders(
          ::Logging.appenders.stdout(
            layout: ::Logging.layouts.pattern(
              pattern: '[%d] %-5l %c: %m\n',
              date_pattern: '%Y-%m-%d %H:%M:%S'
            )
          ),
          ::Logging.appenders.file(
            "log/#{self.name.downcase}.log",
            layout: ::Logging.layouts.pattern(
              pattern: '[%d] %-5l %c: %m\n',
              date_pattern: '%Y-%m-%d %H:%M:%S'
            )
          )
        )
        logger
      end
    end
  end
end
