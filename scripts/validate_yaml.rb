require 'yaml'

def get_current_time
    Time.now.strftime("%Y-%m-%d %H:%M:%S")
end

def validate_yaml(file_path, log_file)
  begin
    File.open(file_path, "r") do |file|
      first_line = file.readline.strip
      return first_line == 'payload:'
    end
    return true
  rescue => e
    File.open(log_file, "a") do |f|
        f.puts "#{get_current_time} Error: YAML 格式有误 ---> #{file_path} 【#{e.message}】"
    end
    return false
  end
end

file_path = ARGV[0]
log_file = ARGV[1]
if validate_yaml(file_path, log_file)
    exit 0
else
    exit 1
end