require '/etc/openclash/rule_provider/scripts/download_rules.rb'
require '/etc/openclash/rule_provider/scripts/log_manager.rb'
require '/etc/openclash/rule_provider/scripts/common/rule_provider_constants.rb' # 此文件通过调用 gen_constants.rb 脚本后自动生成

class FakeDownloadRules

  include Log

  def fake_download
    URLS_TO_BE_REFRESHED.each do |url|
      filtered_url = url.gsub(/\#\{BASE_REFRESH_URL\}/, '')
      yaml_file = BASE_DIR + "/#{filtered_url}.yaml"

      # 删除旧文件并创建新文件
      FileUtils.rm(yaml_file, force: true) rescue nil
      FileUtils.rm(BASE_LOG, force: true) rescue nil
      File.write(yaml_file, "payload:\n  - DOMAIN-SUFFIX,This_is_a_fake_url.com\n")
      log("旧yaml文件 #{yaml_file} 已被替换为假 yaml 文件")
    end

    fork_wait_to_download
  end

  def fork_wait_to_download
    fork do
      wait_for_openclash(Time.now.to_i, 6 * 60)
    end
    exit 0
  end

  def wait_for_openclash(start_time, max_runtime)
    loop do
      # 检查是否超过最大运行时间
      current_time = Time.now.to_i
      elapsed_time = current_time - start_time
      if elapsed_time >= max_runtime
        log_err("--------------- 异步下载任务达到最大运行时间 (#{max_runtime} s)，不再尝试 ---------------")
        break
      end

      files_count = `ls /tmp/yaml_* 2>/dev/null | wc -l`.strip.to_i
      # 由于clash启动失败后也会删除上述文件，所以需要同时检测 clash core 以及 openclash_watchdog.sh 脚本是否已经正常加载并启动
      # /etc/init.d/openclash stop 函数
      clash_core_started = `pidof clash | sed 's/$//g' | wc -l`.strip.to_i
      # /usr/share/openclash/openclash_ps.sh unify_ps_status
      watchdog_started = `ps -efw | grep -v grep | grep -c "openclash_watchdog.sh"`.strip.to_i
      if files_count > 0 || clash_core_started < 1 || watchdog_started < 1
        log("openclash 服务未完成启动，等待5秒后重试......")
        sleep 5
      else
        sleep 2

        log("openclash 服务已经启动开始下载和替换流程...")
        DownloadRules.new.download
        log("异步执行下载和替换逻辑完成，准备退出...")
        break
      end
    end
  end
end

FakeDownloadRules.new.fake_download