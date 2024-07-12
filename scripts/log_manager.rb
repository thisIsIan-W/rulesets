module Log

  def self.included(base)
    base.extend(ClassMethods)
  end

  def self.close_logs
    @logger.close if @logger
    @openclash_logger.close if @openclash_logger
  end

  at_exit do
    close_logs
  end

  def log(message)
    self.class.logger.info(message)
    self.class.openclash_logger.info(message)
  end

  def log_err(message)
    self.class.logger.error(message)
    self.class.openclash_logger.error(message)
  end

  module ClassMethods
    def logger
      @logger ||= Logger.new(BASE_LOG_FILE)
    end

    def openclash_logger
      @openclash_logger ||= Logger.new(OPENCLASH_LOG_FILE)
    end
  end

end