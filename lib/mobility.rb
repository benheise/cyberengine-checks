module Cyberengine
  class Mobility

    # Defaults: Cyberengine.mobility
    attr_reader :id, :mobility, :test, :daemon, :logger, :whiteteam, :pid, :stop, :service
    def initialize(mobility)
      @mobility = mobility
      @id = Cyberengine.config_id(@mobility)
      @test = Cyberengine.config_test(@mobility)
      @daemon = Cyberengine.config_daemon(@mobility)

      # Used for signals
      @stop = false

      # Create paths
      Cyberengine.create_path(Cyberengine.config_pid_dir(@mobility))
      Cyberengine.create_path(Cyberengine.config_log_dir(@mobility))

      # Setup logging
      @logger = Cyberengine::Logging.new(@mobility).logger
  
      # Daemonize
      if @daemon
        pid = Cyberengine.daemonize(@mobility)
        if pid
          @mobility[:daemon] = false
          @daemon = false
          @logger.info { "#{@mobility[:name]} already running with pid: #{pid}" }
          terminate
        end
        @logger.info { "Successfully daemonized" } 
      end
      @pid = Process.pid

      # Database connection
      Cyberengine::Database.new(@logger)

      # Need whiteteam to find defaults
      @whiteteam = Team.find_by_name('Whiteteam')
      raise "Team 'Whiteteam' is required to find defaults" unless @whiteteam

      # Need mobility service for options
      @service = Service.where('team_id = ? AND name = ? AND version = ? AND protocol = ?', @whiteteam.id, @mobility[:name], @mobility[:version], @mobility[:protocol]).first
      raise "#{@mobility[:name]} service is not defined" unless @service
    end

    # Delete pid file 
    def terminate
      pid_file = Cyberengine.config_pid_file(@mobility)
      File.delete(pid_file) if @daemon && File.exists?(pid_file)
      @logger.info { "Successfully terminated" } 
      @logger.close
      exit
    end

    # Trap TERM signal and exit
    def signals
      Signal.trap('TERM') do 
        @logger.info { "Received TERM Signal - Stopping at next oppertunity" }
        @stop = true
      end
    end

    # Default exception logger - log error and continue
    def exception_handler(mobility,exception)
      logs = Array.new
      logs << "Exception #{exception.class} raised during mobility - New: #{mobility[:new_address]} - Current: #{mobility[:current_address]} Previous: #{mobility[:previous_address]}"
      logs << "Exception message: #{exception.message}"
      logs << "Exception backtrace: #{exception.backtrace}"
      logs.each { |log| @logger.error { log } }
    end

    # Fatal exception logger - log and send terminate signal    
    def fatal_exception_handler(exception)
      logs = Array.new
      logs << "Daemon crashed due to #{exception.class}"
      logs << "Exception message: #{exception.message}"
      logs << "Exception backtrace: #{exception.backtrace}"
      logs.each { |log| @logger.fatal { log } }
      Process.kill("TERM", Process.pid)
    end
  end
end
