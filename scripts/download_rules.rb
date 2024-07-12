require 'download_3rd_party_files_util'

class Download3rdPartyRules

  def initialize(base_cfg_file_path)
    if File.exist?(base_cfg_file_path)
      instance_eval(File.read(base_cfg_file_path))
    else
      raise "#{base_cfg_file_path} 配置文件不存在，请检查路径！"
    end
    @locker = Locker.instance
    @logger = Log.new(@log_file_path)
    @openclash_logger = Log.new(@openclash_log_file_path)

    init_parameters
  end

  def init_parameters
    @push_msg = "全部第三方规则集文件更新成功！"
    @push_msg_initial = @push_msg
    @ruleset_types = %w[ipcidr classical domain invalid]
    @rule_downloading_urls = "#{rule_downloading_urls}"
    @tmp_rulesets_file_directory = "#{tmp_rulesets_file_directory}"
    @base_scripts_dir = "#{base_scripts_dir}"
    @base_log_file = "#{base_log_file}"
    @openclash_log_file = "#{openclash_log_file}"
  end

  # 下载主函数
  def download()
    start_time = Time.now

  end

  def curl_request() end

  def determine_cfg_type() end

  def update_cron

  end
end
