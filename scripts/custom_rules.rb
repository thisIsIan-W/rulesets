# 本脚本用于覆写 rule-provider 配置

# 覆写设置 -- 开发者选项 -- exit语句前加入下面两行代码：
# RUBY_FILE="/etc/openclash/rule_provider/scripts/custom_rules.rb"
# /usr/bin/ruby -e "require '$RUBY_FILE'; write_custom_rules('$CONFIG_FILE', '$LOG_FILE')" >> /tmp/openclash.log 2>&1

require 'yaml'
require '/etc/openclash/rule_provider/scripts/download_rules.rb'

def gen_cfg_files
  rules_cfg_path = "/etc/openclash/rule_provider/scripts/common/rule_provider_constants.rb"
  yaml_cfg_path = "/etc/openclash/rule_provider/scripts/common/rule_providers.yaml"

  File.open(rules_cfg_path, 'w') do |file|
    # Heredoc 不处理缩进，如果需要在写入时保留缩进，就用 <<EOF ... EOF
    # 写入到文件时不进行插值计算，使用 \#{...} 即可
    script = <<~EOF
      BASE_DIR = "/etc/openclash/rule_provider"
      BASE_SCRIPTS_DIR = "\#{BASE_DIR}/scripts"
      BASE_LOG_FILE = "\#{BASE_DIR}/rulesets_download_&_refresh.log"
      OPENCLASH_LOG_FILE = "/tmp/openclash.log"
      
      # 只能处理内容为yaml格式的文件，后缀名无所谓
      # 为了统一格式，省去人为判断 behavior 的麻烦、部分提升匹配效率，所有文件都会被转换成 classical 类型
      RULE_DOWNLOADING_URLS = %w[
        https://raw.githubusercontent.com/thisIsIan-W/rulesets/main/configs/my-direct.yaml
        https://raw.githubusercontent.com/thisIsIan-W/rulesets/main/configs/my-proxy.yaml
        https://raw.githubusercontent.com/thisIsIan-W/rulesets/main/configs/my-reject.yaml
        https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/cncidr.txt
        https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/reject.txt
      ]
      
      # 指定PATH，否则运行运行期间找不到uci命令(/sbin/uci)
      ENV['PATH'] = '/sbin:/usr/sbin:/bin:/usr/bin'
      IP_ADDR = `uci -q get network.lan.ipaddr`.strip
      CN_PORT = `uci -q get openclash.config.cn_port`.strip.to_i
      DASHBOARD_PASSWORD = `uci -q get openclash.config.dashboard_password`.strip
      BASE_REFRESH_URL = "http://\#{IP_ADDR}:\#{CN_PORT}/providers/rules/"
      
      URLS_TO_BE_REFRESHED = %w[
        \#{BASE_REFRESH_URL}my-proxy
        \#{BASE_REFRESH_URL}my-direct
        \#{BASE_REFRESH_URL}my-reject
        \#{BASE_REFRESH_URL}cncidr
        \#{BASE_REFRESH_URL}reject
      ]
    EOF
    file.puts script
  end
  # rb 文件需要给 +x 权限
  File.chmod(0755, rules_cfg_path)

  # For shell scripts end...

  # 以下代码会被 custom_rules.rb 调用，作用是导入自定义规则集到 yaml 中
  # 不要格式化！！！
  # 不要格式化！！！
  # 不要格式化！！！
  File.open(yaml_cfg_path, 'w') do |file|
    file.puts 'priority_custom_rules:
  - RULE-SET,my-proxy,😀 MY-PROXY
  - RULE-SET,my-reject,REJECT
  - RULE-SET,reject,REJECT
extended_custom_rules:
  - RULE-SET,my-direct,DIRECT
  - RULE-SET,cncidr,DIRECT,no-resolve
rule-providers:
  reject:
    type: file
    behavior: classical
    path: ./rule_provider/reject.yaml
    format: yaml
  cncidr:
    type: file
    behavior: classical
    path: ./rule_provider/cncidr.yaml
    format: yaml
  my-proxy:
    type: file
    behavior: classical
    path: ./rule_provider/my-proxy.yaml
    format: yaml
  my-direct:
    type: file
    behavior: classical
    path: ./rule_provider/my-direct.yaml
    format: yaml
  my-reject:
    type: file
    behavior: classical
    path: ./rule_provider/my-reject.yaml
    format: yaml'
  end

  [rules_cfg_path, yaml_cfg_path]
end

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

def write_custom_rules(config_file, log_file, fake)
  begin
    File.open(log_file, "a") do |f|
      f.puts "#{get_current_time} 准备导出所有自定义 rule-providers 到配置文件中 ==> #{config_file}"
    end

    # 生成yaml及sh配置
    rules_cfg_path, yaml_cfg_path = gen_cfg_files
    value = YAML.load_file(config_file)

    custom_yaml_data = YAML.load_file(yaml_cfg_path)
    append_rules(value, custom_yaml_data, log_file)
    insert_rule_providers(config_file, value, custom_yaml_data, log_file)

    File.open(log_file, "a") do |f|
      f.puts "#{get_current_time} 导出所有自定义 rule-providers 到配置文件 ==> #{config_file} 中成功！"
    end

    # 异步下载
    DownloadRules.new.download(fake)
  rescue Exception => e
    File.open(log_file, "a") do |f|
      f.puts "#{get_current_time} Error: YAML 加载 #{config_file} 出现异常，不再继续执行下去 ==>【#{e.message}】"
    end
    return
  end
end

write_custom_rules(ARGV[0], ARGV[1], ARGV[2])