require 'logger'
require 'fileutils'

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
        FileUtils.mkdir_p('log') unless Dir.exist?('log')
        logger = Logger.new(MultiIO.new(STDOUT, File.open("log/#{self.name.downcase}.log", 'a')))
        logger.level = Logger.const_get(Configuration.instance.log_level.upcase)
        logger.formatter = proc do |severity, datetime, progname, msg|
          "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity} #{self.name}: #{msg}\n"
        end
        logger
      end
    end
  end

  class MultiIO
    def initialize(*targets)
      @targets = targets
    end

    def write(*args)
      @targets.each { |t| t.write(*args) }
    end

    def close
      @targets.each(&:close)
    end
  end
end
