# 本脚本用于覆写 rule-provider 配置
require 'yaml'

def get_current_time
    Time.now.strftime("%Y-%m-%d %H:%M:%S")
end

def write_custom_rules(config_file, log_file)
    begin
        value = YAML.load_file(config_file);
    rescue Exception => e
        File.open(log_file, "a") do |f|
            f.puts "#{get_current_time} Error: YAML 加载 #{config_file} 出现异常，不再继续执行下去 ==>【#{e.message}】"
        end
        return
    end
    
    append_rules(value, log_file)
    insert_rule_providers(config_file, value, log_file)
end

def append_rules(value, log_file)
    # 找到 rules 标签
    rules = value['rules']

    # 追加新的配置
    priority_custom_rules = [
        'RULE-SET,my-proxy,PROXY_MANUAL',
        'RULE-SET,telegramcidr,PROXY_MANUAL,no-resolve',
        'RULE-SET,my-reject,REJECT',
        'RULE-SET,cncidr,DIRECT,no-resolve'
    ]
    extended_custom_rules = [
        'RULE-SET,my-direct,DIRECT',
        'RULE-SET,direct,DIRECT'
    ]

    # 分别找到2个标记位并在其后插入上述内容(已在github上新增)
    # 初始化标记变量
    found_priority = false
    found_extended = false
    # 遍历 rules 数组，查找包含特定字符串的行并插入新的规则数据
    rules.each_with_index do |rule, index|
        if rule.include?('priority-custom-rules-tobe-inserted-by-IAN')
            begin
                rules.insert(index + 1, priority_custom_rules)
            rescue Exception => e
                File.open(log_file, "a") do |f|
                    f.puts "#{get_current_time} Error: 在 priority-custom-rules-tobe-inserted-by-IAN 后写入规则出现异常 ==>【#{e.message}】"
                end
            ensure
                found_priority = true
            end
                
        elsif rule.include?('extended-custom-rules-tobe-inserted-by-IAN')
            begin
                rules.insert(index + 1, extended_custom_rules)
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

def insert_rule_providers(config_file, value, log_file)
    # 追加 rule-providers
    rule_providers = {
        "rule-providers" => {
            "telegramcidr" => {
                "type" => "file",
                "behavior" => "ipcidr",
                "path" => "./rule_provider/telegramcidr.yaml",
                "format" => "yaml"
            },
            "my-proxy" => {
                "type" => "file",
                "behavior" => "classical",
                "path" => "./rule_provider/my-proxy.yaml",
                "format" => "yaml"
            },
            "cncidr" => {
                "type" => "file",
                "behavior" => "ipcidr",
                "path" => "./rule_provider/cncidr.yaml",
                "format" => "yaml"
            },
            "my-direct" => {
                "type" => "file",
                "behavior" => "classical",
                "path" => "./rule_provider/my-direct.yaml",
                "format" => "yaml"
            },
            "direct" => {
                "type" => "file",
                "behavior" => "classical",
                "path" => "./rule_provider/direct.yaml",
                "format" => "yaml"
            },
            "my-reject" => {
                "type" => "file",
                "behavior" => "classical",
                "path" => "./rule_provider/my-reject.yaml",
                "format" => "yaml"
            }
        }
    }

    Thread.new do
        # 使用 Mutex 来确保线程安全
        mutex = Mutex.new
        mutex.synchronize do
            begin
                value['rule-providers'] = rule_providers
                File.open(config_file, 'w') { |f| YAML.dump(value, f) }
            rescue Exception => e
                File.open(log_file, "a") do |f|
                    f.puts "#{get_current_time} Error: 新增 rule-providers 失败,【#{e.message}】"
                end
            end
        end
    end.join
end