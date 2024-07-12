require 'logger'
require 'singleton'

class CommonUtils

  def self.encrypted_device_info
    encrypted_device_info = {}
    encrypted_device_info["encrypted_device_key"] = "U2FsdGVkX19JoDCN9YkkGBB3bQGe4weTdLMQr/e4j++mgIW2m34FdQB4HX8QlxnQ"
    encrypted_device_info["encrypted_key"] = "U2FsdGVkX18Tch9LZrXlwn3Xl7OnXgCjP+HvQFlLJD+zwMtnivcRTJewqUDXY37R"
    encrypted_device_info["encrypted_iv"] = "U2FsdGVkX19VYMZqYNojhuOfHLCFJh4wNdqoLPC/NGchh9+rWns5hurxEoHyltz8"
  end

  def self.get_push_device_info(file_path)
    device_info = {}
    File.open(file_path, 'r') do |file|
      file.each_line do |line|
        pairs = line.split("=")
        key = pairs[0].strip
        val = pairs[1].strip
        device_info[key] = val
      end
    end
    device_info
  end

  def self.current_time_sec
    Time.now.to_i
  end

  def self.curl_request(url, request_data_map, use_ssl: true, method: 'GET')
    request = Net::HTTP.const_get(method.capitalize).new(URI(url))
    request.set_form_data(request_data_map)

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl) do |http|
      http.request(request)
    end
  end
end

class Log
  def initialize(file_path, level: Logger::INFO, datetime_format: '%Y-%m-%d %H:%M:%S')
    @logger = Logger.new(file_path)
    @logger.level = level
    @logger.datetime_format = datetime_format
    @file_path = file_path
    @file_lock = Locker.instance
  end

  def logger
    @logger
  end

  def flush_log
    begin
      @file_lock.acquire_lock
      if File.exist?(@file_path)
        File.open(@file_path, 'w') {}
      end
    ensure
      @file_lock.release_lock
    end
  end
end

class Locker
  include Singleton

  def initialize
    @locker = Mutex.new
  end

  def acquire_lock
    @locker.lock
  end

  def release_lock
    @locker.unlock
  end
end

def abc
  logger_instance = Log.new("G:/openclash.log")
  logger_instance.logger.info("sdfsad")
  logger_instance.flush_log
  logger_instance.logger.info("hahahahah")
end

abc
