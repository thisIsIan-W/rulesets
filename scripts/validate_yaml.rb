require 'yaml'

def get_current_time
  Time.now.strftime("%Y-%m-%d %H:%M:%S")
end

# 动态调用函数并传递参数
# def execute_method(method_name, *parameters)
#   if method_name && respond_to?(method_name)
#     send(method_name, *parameters)
#   else
#     log_file = parameters[1]
#     File.open(log_file, "a") do |f|
#       f.puts "#{get_current_time} Error: 未定义函数 【#{method_name}】, parameters ==> 【#{parameters}】 请检查代码！"
#     end
#     exit(false) # 使用 exit 终止脚本执行，并返回 false 作为退出状态
#   end
# end

def is_validate_yaml(file_path, log_file)
  if File.exist?(file_path)
    begin
      YAML.load_file(file_path)
      true
    rescue => e
      File.open(log_file, "a") do |f|
        f.puts "#{get_current_time} Error: YAML 格式有误 ---> #{file_path} 【#{e.message}】"
      end
      false
    end
  end
  false
end

def is_first_line_payload(file_path, log_file)
  if File.exist?(file_path)
    begin
      # 校验文件的第一行是不是payload:
      File.open(file_path, 'r:bom|utf-8') do |file|
        first_line = file.readline.strip
        return first_line == 'payload:'
      end
      true
    rescue => e
      File.open(log_file, "a") do |f|
        f.puts "#{get_current_time} Error: YAML 格式有误 ---> #{file_path} 【#{e.message}】"
      end
      false
    end
  end
  false
end