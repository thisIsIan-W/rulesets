# 本脚本用于覆写 rule-provider 配置

# 覆写设置 -- 开发者选项 -- exit语句前加入下面两行代码：
# RUBY_FILE="/etc/openclash/rule_provider/scripts/custom_rules.rb"
# /usr/bin/ruby -e "require '$RUBY_FILE'; write_custom_rules('$CONFIG_FILE', '$LOG_FILE')" >> /tmp/openclash.log 2>&1

require 'yaml'
require_relative 'gen_cfg_files'

def get_current_time
  Time.now.strftime("%Y-%m-%d %H:%M:%S")
end

def append_rules(value, custom_yaml_data, log_file)
  # 找到 rules 标签
  rules = value['rules']

  # 分别找到2个标记位并在其后插入上述内容(已在github上新增)
  found_priority = false
  found_extended = false
  # 遍历 rules 数组，查找包含特定字符串的行并插入新的规则数据
  rules.each_with_index do |rule, index|
    if rule.include?('priority-custom-rules-tobe-inserted-by-IAN')
      begin
        rules.insert(index + 1, *custom_yaml_data['priority_custom_rules'])
      rescue Exception => e
        File.open(log_file, "a") do |f|
          f.puts "#{get_current_time} Error: 在 priority-custom-rules-tobe-inserted-by-IAN 后写入规则出现异常 ==>【#{e.message}】"
        end
      ensure
        found_priority = true
      end

    elsif rule.include?('extended-custom-rules-tobe-inserted-by-IAN')
      begin
        rules.insert(index + 1, *custom_yaml_data['extended_custom_rules'])
      rescue Exception => e
        File.open(log_file, "a") do |f|
          f.puts "#{get_current_time} Error: 在 extended-custom-rules-tobe-inserted-by-IAN 后写入规则出现异常 ==>【#{e.message}】"
        end
      ensure
        found_extended = true
      end
    end
    break if found_priority && found_extended
  end
end

def insert_rule_providers(config_file, value, custom_yaml_data, log_file)
    begin
      value['rule-providers'] ||= {}

      File.open(log_file, "a") do |f|
        f.puts "#{get_current_time} custom_yaml_data['rule-providers'] ====> \n #{custom_yaml_data['rule-providers']}"
      end

      custom_rule_providers = custom_yaml_data['rule-providers'] || {}
      value['rule-providers'].merge!(custom_rule_providers)
      File.open(config_file, 'w') { |f| YAML.dump(value, f) }
    rescue Exception => e
      File.open(log_file, "a") do |f|
        f.puts "#{get_current_time} Error: 新增 rule-providers 失败,【#{e.message}】"
      end
    end
end

def write_custom_rules(config_file, log_file, fake_generate)
  begin
    File.open(log_file, "a") do |f|
      f.puts "#{get_current_time} 准备导出所有自定义 rule-providers 到配置文件中 ==> #{config_file}"
    end

    # 生成yaml及sh配置, gen_cfg_files 函数由顶部 require_relative 'gen_cfg_files' 导入
    shell_cfg_path, yaml_cfg_path, download_files_shell_path = gen_cfg_files

    value = YAML.load_file(config_file)
    custom_yaml_data = YAML.load_file("#{yaml_cfg_path}")
    append_rules(value, custom_yaml_data, log_file)
    insert_rule_providers(config_file, value, custom_yaml_data, log_file)

    fake_generate.nil? || fake_generate.empty? ?
    system("bash \"#{download_files_shell_path}\" \"#{shell_cfg_path}\"") :
    system("bash \"#{download_files_shell_path}\" \"#{shell_cfg_path}\" \"fake_generate\"")

    File.open(log_file, "a") do |f|
      f.puts "#{get_current_time} 导出所有自定义 rule-providers 到配置文件 ==> #{config_file} 中成功！"
    end
  rescue Exception => e
    File.open(log_file, "a") do |f|
      f.puts "#{get_current_time} Error: YAML 加载 #{config_file} 出现异常，不再继续执行下去 ==>【#{e.message}】"
    end
    return
  end
end