module Cyberengine
  class Logging
    require 'logger'
    require_relative 'multi_io'
    require_relative 'pretty_formatter'
    
    attr_accessor :logger
    def initialize(check)
      log_file = Cyberengine.config_log_file(check)
      @logger = Logger.new(log_file)
      @logger.formatter = Cyberengine::PrettyFormatter.new
    end

  end
end
