require 'concurrent'
require 'thread'
require 'net/http'
require 'tempfile'
require 'fileutils'
require 'yaml'
# 由于 openclash 启动脚本目录和当前脚本所在目录不一致，所以自己的脚本需要用绝对路径引入
require '/etc/openclash/rule_provider/scripts/download_rules_util.rb'
require '/etc/openclash/rule_provider/scripts/log_manager.rb'
require '/etc/openclash/rule_provider/scripts/replace_files_by_regex.rb'
require '/etc/openclash/rule_provider/scripts/common/rule_provider_constants.rb' # 此文件通过调用 gen_constants.rb 脚本后自动生成

$push_message = "全部第三方规则集文件更新成功！"
$push_msg_initial = $push_message

def append_push_message(file_name)
  Mutex.new.synchronize do
    if $push_message == $push_msg_initial
      $push_message = ""
    end
    $push_message += "#{file_name}, "
  end
end


class ThreadPoolManager

  def initialize(size)
    init_pool(size)
  end

  def init_pool(size)
    @thread_pool = Concurrent::FixedThreadPool.new(size)
  end

  def submit_task(&task)
    raise '线程池还未初始化......' unless @thread_pool
    @thread_pool.post(&task)
  end

  def shutdown_pool
    if @thread_pool
      @thread_pool.shutdown
      @thread_pool.wait_for_termination
    end
  end
end

class DownloadRules

  include Log

  def initialize
    init_thread_pool
    @mutex = Mutex.new
  end

  private

  def init_thread_pool
    @thread_pool = ThreadPoolManager.new(4)
  end

  public

  def download
    do_download
  end

  def do_download
    start_time = Time.now.to_i
    latch = CountDownLatch.new(@mutex, RULE_DOWNLOADING_URLS.length)

    RULE_DOWNLOADING_URLS.each do |downloading_url|

      @thread_pool.submit_task do
        begin
          exec_http_request = ExecHttpRequest.new
          if exec_http_request.exec_http_request(downloading_url, file_dir: "#{BASE_DIR}/#{File.basename(downloading_url)}") == 0
            exec_after_download("#{BASE_DIR}/#{File.basename(downloading_url)}")
          end
        ensure
          latch.count_down
        end
      end
    end

    log("等待所有下载、替换操作执行完成...")
    latch.await

    # 发push给手机
    $push_message = $push_message.sub(/, $/, '') + " 下载或执行失败！" unless $push_msg_initial == $push_message
    Push.new.push($push_message)

    # 刷新配置
    RefreshRules.new.refresh
    log("所有下载、替换操作已经执行完成，耗时#{Time.now.to_i - start_time}")

    @thread_pool.shutdown_pool
  end

  def exec_after_download(file_full_dir)
    file_lines = File.readlines(file_full_dir).size
    file_name = File.basename(file_full_dir)

    begin
      `sed -i '/^[[:space:]]*(#|$)/! { /^payload:/b; /:/d;}' #{file_full_dir}`
    rescue Exception => e
      log_err("删除 #{file_name} 中所有的IPV6行出现异常：#{e.to_s}")
      return
    end

    is_invalid_file = 0
    exec_result = 0
    replace_rule_files = ReplaceRuleFiles.new
    begin
      if File.extname(file_name).downcase == '.yaml' || File.extname(file_name).downcase == '.yml'
        exec_result = replace_rule_files.common_rules_replace(file_full_dir)
      else
        rule_file_type = replace_rule_files.determine_rule_file_type(file_full_dir).to_s
        if rule_file_type == "domain" || rule_file_type == "classical"
          exec_result = replace_rule_files.common_rules_replace(file_full_dir)
        elsif rule_file_type == "ipcidr"
          exec_result = replace_rule_files.ipcidr_rules_replace(file_full_dir)
        else
          log_err("文件 #{file_name} 格式无效，跳过它。请检查源链接是否正确")
          is_invalid_file = 1
        end

        # 覆盖源文件，ruby中使用 "#{}" 语法是为了在字符串中插入变量或表达式的值
        file_new_dir = File.join("#{File.dirname(file_full_dir)}", "#{File.basename(file_full_dir, ".*")}.yaml")
        File.rename(file_full_dir, file_new_dir)
        file_full_dir = file_new_dir
      end

      replace_rule_files.insert_payload(file_full_dir)
    rescue Exception => e
      log_err("#{e.message}")
      return
    end

    if is_invalid_file == 0 && exec_result == 0
      flag = replace_rule_files.is_validate_yaml(file_full_dir)
      if flag
        lines_after_trim = File.readlines(file_full_dir).size
        log("#{file_full_dir} 文件修改前【#{file_lines}】行，" \
                   "修改后剩余【#{lines_after_trim}】行，删除了【#{file_lines - lines_after_trim}】行")
      else
        log_err("#{File.basename(file_full_dir)} 文件内容不合法，请检查！")
      end
    end
  end

end


class CountDownLatch

  def initialize(mutex, count)
    @mutex = mutex
    @cv = ConditionVariable.new
    @count = count
  end

  def await
    @mutex.synchronize do
      @cv.wait(@mutex) while @count > 0
    end
  end

  def count_down
    @mutex.synchronize do
      @count -= 1
      @cv.signal if @count <= 0
    end
  end
end

class ExecHttpRequest

  include Log

  def exec_http_request(url, file_dir: nil, method: 'GET', use_ssl: true)
    file_name = File.basename(url)
    uri = URI.parse(url)
    request = Net::HTTP.const_get(method.capitalize).new(uri)
    begin
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl) do |http|
        response = http.request(request)
        if response.code.to_i == 200

          unless file_dir.nil?
            File.open(file_dir, 'w') do |file|
              file.write(response.body)
            end
            log("文件 #{file_name} 已下载到 #{file_dir}")
          end

          return 0
        else
          unless file_dir.nil?
            log_err("文件 #{file_name} 下载失败，状态码：#{response.code}，信息：#{response.message}")
            append_push_message(file_name)
          end
          return response.code.to_i
        end
      end
    rescue Exception => e
      unless file_dir.nil?
        log_err("文件 #{file_name} 下载出错，#{e.message}")
        append_push_message(file_name)
      end
      return 1
    end
  end

end

class RefreshRules

  def initialize
    @ip_addr = `uci -q get network.lan.ipaddr`.strip
    @cn_port = `uci -q get openclash.config.cn_port`.strip.to_i
    @dashboard_password = `uci -q get openclash.config.dashboard_password`.strip
    @base_refresh_url = "http://#{@ip_addr}:#{@cn_port}/providers/rules/"
    @base_dashboard_auth_token = "Bearer #{@dashboard_password}"
    @urls_to_be_refreshed = [
      "#{@base_refresh_url}my-proxy", #
      "#{@base_refresh_url}my-direct",
      "#{@base_refresh_url}my-reject",
      "#{@base_refresh_url}reject",
      "#{@base_refresh_url}cncidr"
    ]
  end

  def refresh
    exec_http_request = ExecHttpRequest.new
    @urls_to_be_refreshed.each do |url|
      exec_http_request.exec_http_request(url, file_dir: nil, method: 'PUT', use_ssl: false)
    end
  end
end

# DownloadRules.new.download