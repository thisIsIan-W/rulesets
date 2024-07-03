require 'open-uri'

def get_current_time
    Time.now.strftime("%Y-%m-%d %H:%M:%S")
end

mirror_urls = [
    'https://testingcf.jsdelivr.net/gh/thisIsIan-W/rulesets@release/scripts/',
    'https://fastly.jsdelivr.net/gh/thisIsIan-W/rulesets@release/scripts/',
    'https://gcore.jsdelivr.net/gh/thisIsIan-W/rulesets@release/scripts/',
    'https://cdn.jsdelivr.net/gh/thisIsIan-W/rulesets@release/scripts/',
    'https://raw.githubusercontent.com/thisIsIan-W/rulesets/release/scripts/'
]

def download_all(ConfigFile, LogFile)
    download_rules(ConfigFile, LogFile, 'custom_rules.rb', '/etc/openclash')
    download_rules(ConfigFile, LogFile, 'rulesets_scripts.sh', '/etc/openclash/rule-provider')
end

def download_rules(ConfigFile, LogFile, Filename, TargetDirectory)
    download_count = 0
    save_path = ""
    mirror_urls.each do |url|
        begin
            file_name = File.basename(url) + Filename
            save_path = File.join(TargetDirectory, file_name)

            open(url, 'rb') do |file|
                File.open(save_path, 'wb') do |f|
                    f.write(file.read)
                end

                 # 下载成功后设置文件权限为可执行
                File.chmod(0755, save_path)

                File.open(LogFile, "a") do |f|
                    f.puts "#{get_current_time} 下载 custom_rules.rb 成功！"
                end

                # 如果成功下载则跳出循环
                break
            end
        rescue StandardError => e
            # 如果下载失败，则捕获异常并输出错误信息并继续尝试下一个 URL
            File.open(LogFile, "a") do |f|
                f.puts "#{get_current_time} Error: 下载 custom_rules.rb 出现异常, message =>【#{e.message}】"
            end
            next
        ensure
            download_count += 1
        end
    end

    if download_count == mirror_urls.size
        File.open(LogFile, "a") do |f|
            f.puts "#{get_current_time} Error: 所有CDN都无法成功下载 custom_rules.rb 文件，不再执行覆写及下载三方规则集逻辑【#{e.message}】"
        end
        return
    end

    # 加载并执行下载的 Ruby 文件
    load(save_path)

    # 调用函数并传递参数
    if respond_to?("write_custom_rules")
        send("write_custom_rules", *[ConfigFile, LogFile])
    end
end