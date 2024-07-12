# For shells scripts start...
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

gen_cfg_files
