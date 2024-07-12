require '/etc/openclash/rule_provider/scripts/log_manager.rb'
require '/etc/openclash/rule_provider/scripts/download_rules_util.rb'

class ReplaceRuleFiles

  include Log

  def determine_rule_file_type(file_full_dir)
    begin
      valid_line_count = `awk '!/^[[:space:]]*(#|$)/ && !/payload:/ && NF > 0' #{file_full_dir} | wc -l`.strip.to_i
      # 排除掉payload行、空白行、空字符串行、注释行之后剩余的行、且仅包含ip类型的行的数量
      ip_line_count = `awk '!/^[[:space:]]*(#|$)/ && !/payload:/ && NF > 0' "#{file_full_dir}" \
        | grep -E -o "'?[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}/[0-9]{1,2}'?" \
        | wc -l`.strip.to_i
      exclude_ip_line_count = valid_line_count - ip_line_count
      if exclude_ip_line_count.to_i == 0
        return "ipcidr"
      elsif exclude_ip_line_count.to_i == valid_line_count
        return "domain"
      elsif exclude_ip_line_count.to_i > 0
        return "classical"
      else
        return "invalid"
      end
    rescue Exception => e
      log_err("确定文件最终的 behavior 时出现错误：【#{e.message}】")
      return "invalid"
    end
  end

  def common_rules_replace(source_dir)

    begin
      # Open3 可以捕获更详细的标准输出和标准错误
      command = %Q{sed -i -e "s/'$//g" \
            -e "s/  - '+./  - DOMAIN-SUFFIX,/g" \
            -e "s/  - '/  - DOMAIN,/g" \
            -e "s/  - 'SRC-IP-CIDR/  - SRC-IP-CIDR/g" \
            -e "s/  - 'IP-CIDR/  - IP-CIDR/g" \
            {source_dir} \
      }
      stderr, status = ExecShellCommand.exec_shell_command(command, source_dir: source_dir)
      unless status.exitstatus == 0
        raise stderr
      end
    rescue Exception => e
      log_err("常规文件【#{File.basename(source_dir)}】替换rule-set关键字时出错：#{e.to_s}")
      1
    end

    begin
      command = %Q{
        sed -i -E '/^[[:space:]]*(#|$)/! { \
              /^  - (IP-CIDR|SRC-IP-CIDR)/ { \
                  /,no-resolve$/! { s/$/,no-resolve/ } \
              } \
          }' {source_dir} \
      }
      stderr, status = ExecShellCommand.exec_shell_command(command, source_dir: source_dir)
      unless status.exitstatus == 0
        raise stderr
      end
    rescue Exception => e
      log_err("常规文件【#{File.basename(source_dir)}】为规则结尾添加no-resolve关键字时出错：#{e.to_s}")
      1
    end

    0
  end

  def ipcidr_rules_replace(source_dir)
    begin
      command = %Q{ \
        sed -i -e "s/'$//g" \
            -e "s/  - '/  - IP-CIDR,/g" \
            -e "s/  - 'SRC-IP-CIDR/  - SRC-IP-CIDR/g" \
            -e "s/  - 'IP-CIDR/  - IP-CIDR/g" \
            -e "s/'IP-CIDR/  - IP-CIDR/g" \
            -e "s/'SRC-IP-CIDR/  - SRC-IP-CIDR/g" \
            -e "/^  - IP-CIDR/! s/IP-CIDR/  - IP-CIDR/g" \
            -e "/^  - SRC-IP-CIDR/! s/SRC-IP-CIDR/  - SRC-IP-CIDR/g" \
          {source_dir}
      }
      stderr, status = ExecShellCommand.exec_shell_command(command, source_dir: source_dir)
      unless status.exitstatus == 0
        raise stderr
      end
    rescue Exception => e
      log_err("ip规则文件【#{File.basename(source_dir)}】执行rule-set关键字替换时出错：#{e.to_s}")
      1
    end

    begin
      # 有些文件内容是纯ip，这里替换
      command = %Q{sed -i -E '/^  - IP-CIDR/! { /\\<([0-9]{1,3}\\.){3}[0-9]{1,3}\\>/ s/(.*)/  - IP-CIDR,\\1/ }' {source_dir}}
      stderr, status = ExecShellCommand.exec_shell_command(command, source_dir: source_dir)
      unless status.exitstatus == 0
        raise stderr
      end
    rescue Exception => e
      log_err("ip规则文件【#{File.basename(source_dir)}】新增IP-CIDR前缀时出错：#{e.to_s}")
      1
    end

    begin
      command = %Q{sed -i -E '/^[[:space:]]*(#|$)/! { /^  - (IP-CIDR|SRC-IP-CIDR)/ { /,no-resolve$/! { s/$/,no-resolve/ } } }' {source_dir} }
      stderr, status = ExecShellCommand.exec_shell_command(command, source_dir: source_dir)
      unless status.exitstatus == 0
        raise stderr
      end
    rescue Exception => e
      log_err("ip规则文件【#{File.basename(source_dir)}】新增no-resolve后缀时出错：#{e.to_s}")
      1
    end

    0
  end

  def insert_payload(source_dir)
    payload_count = `awk '!/^[[:space:]]*(#|$)/ && /payload:/ && NF > 0' #{source_dir} | wc -l`.strip.to_i
    if payload_count == 0
      begin
        command = %Q{sed -i "1ipayload:" {source_dir}}
        stderr, status = ExecShellCommand.exec_shell_command(command, source_dir: source_dir)
        unless status.exitstatus == 0
          raise stderr
        end
      rescue Exception => e
        log_err("规则文件【#{File.basename(source_dir)}】新增payload:行时出错：#{e.to_s}")
        1
      end
    end
  end

  def is_validate_yaml(file_path)
    if File.exist?(file_path)
      begin
        yaml_data = YAML.load_file(file_path)
        has_payload = yaml_data.is_a?(Hash) && yaml_data.key?('payload')
        return has_payload
      rescue => e
        log_err("YAML 格式有误 ---> #{file_path} 【#{e.message}】")
        false
      end
    else
      log_err("文件【#{File.basename(file_path)}】 不存在！")
      false
    end
  end
end