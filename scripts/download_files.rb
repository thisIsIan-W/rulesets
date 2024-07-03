require 'open-uri'

def get_current_time
    Time.now.strftime("%Y-%m-%d %H:%M:%S")
end

def download_all(config_file, log_file)
    flag = download_rules(config_file, log_file, 'custom_rules.rb', '/etc/openclash')
    if flag == true
        download_rules(config_file, log_file, 'rulesets_scripts.sh', '/etc/openclash/rule_provider')
    end
end


def download_by_system(target_directory, file_url)
    flag = system("wget -P #{target_directory} #{file_url}")
    return flag
end

def download_rules(config_file, log_file, filename, target_directory)
    save_path = target_directory + "/" + filename
    mirror_urls = [
        'https://raw.githubusercontent.com/thisIsIan-W/rulesets/release/scripts/',
        'https://testingcf.jsdelivr.net/gh/thisIsIan-W/rulesets@release/scripts/',
        'https://fastly.jsdelivr.net/gh/thisIsIan-W/rulesets@release/scripts/',
        'https://gcore.jsdelivr.net/gh/thisIsIan-W/rulesets@release/scripts/',
        'https://cdn.jsdelivr.net/gh/thisIsIan-W/rulesets@release/scripts/'
    ]

    download_count = 0
    mirror_urls.each do |url|
        begin
            if File.exist?(save_path)
                break
            end
            file_url = url + filename
            flag = download_by_system(target_directory, file_url)
            if flag
                File.open(log_file, "a") do |f|
                    f.puts "#{get_current_time} info: 下载 #{filename} 成功！"
                end
                break        
            end
        rescue Exception => e
            # 如果下载失败，则捕获异常并输出错误信息并继续尝试下一个 URL
            File.open(log_file, "a") do |f|
                f.puts "#{get_current_time} Error: 下载 #{filename} 出现异常, message =>【#{e.message}】"
            end
            next
        ensure
            download_count += 1
        end
    end

    if download_count >= mirror_urls.size
        File.open(log_file, "a") do |f|
            f.puts "#{get_current_time} Error: 所有CDN都无法成功下载 #{filename} 文件，不再执行后续逻辑！！！"
        end
        return false
    end

    if File.extname(save_path).downcase == '.rb'
        File.open(log_file, "a") do |f|
            f.puts "#{get_current_time} 准备加载 #{save_path} 文件"
        end
        # 加载并执行下载的 Ruby 文件
        load(save_path)
        File.open(log_file, "a") do |f|
            f.puts "#{get_current_time} 加载 #{save_path} 文件成功！！！"
        end

        write_custom_rules(config_file, log_file)
        return true
    end

    exec_shell(save_path, filename, log_file)
end

def exec_shell(save_path, filename, log_file)
    begin
        shell_command = "bash #{save_path} #{log_file}"
        File.open(log_file, "a") do |f|
            f.puts "#{get_current_time} 准备调用 rulesets_scripts.sh 文件！！！"
        end
        system(shell_command)
        File.open(log_file, "a") do |f|
            f.puts "#{get_current_time} 调用 rulesets_scripts.sh 文件OKOKOKOKOKOKOKOKOKOKOKOK！！！"
        end
    rescue
        File.open(log_file, "a") do |f|
            f.puts "#{get_current_time} Error: 执行 #{filename} 脚本出现异常, message =>【#{e.message}】"
        end
    end
end