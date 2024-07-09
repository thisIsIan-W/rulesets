#!/bin/bash
# 以下配置写入：覆写设置 => 开发者选项 => exit 0 之前粘贴以下两行：
# 需要先把脚本文件保存在 /etc/openclash/rule_provider/scripts 文件夹下
# RUBY_FILE="/etc/openclash/rule_provider/scripts/custom_rules.rb"
# if [ -e "$RUBY_FILE" ]; then
#   ruby -e "require '$RUBY_FILE'; write_custom_rules('$CONFIG_FILE', '$LOG_FILE', 'fake_generate')" 2>"$LOG_FILE"
# fi

shell_cfg_path=$1
fake_generate=$2
if [ -z "$shell_cfg_path" ]; then
    shell_cfg_path="/etc/openclash/rule_provider/scripts/common/rule_provider_urls_cfg.sh"
fi

. $shell_cfg_path

PUSH_MSG="全部第三方规则集文件更新成功！"
PUSH_MSG_INITIAL="$PUSH_MSG"
RULESET_TYPES=(
    "ipcidr"
    "classical"
    "domain"
    "invalid"
)
LOCK_FILE="/tmp/download_rulesets.lock"

count_file_lines() {
    cat $1 | wc -l 2>/dev/null
}
logger() {
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') $*" >>"$BASE_LOG_FILE"
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') $*" >>"$OPENCLASH_LOG_FILE"
}
flush_log() {
    echo -n "" >"$BASE_LOG_FILE"
}
current_millis() {
    echo $(($(date +%s%3N)))
}
aquire_lock() {
    exec 999>"$LOCK_FILE" 2>/dev/null
    flock -x 888 2>/dev/null
}
release_lock() {
    flock -u 999 2>/dev/null
}

do_push() {
    # Documentation: https://bark.day.app/#/encryption
    encrypted_deviceKey="U2FsdGVkX19JoDCN9YkkGBB3bQGe4weTdLMQr/e4j++mgIW2m34FdQB4HX8QlxnQ"
    encrypted_key="U2FsdGVkX18Tch9LZrXlwn3Xl7OnXgCjP+HvQFlLJD+zwMtnivcRTJewqUDXY37R"
    encrypted_iv="U2FsdGVkX19VYMZqYNojhuOfHLCFJh4wNdqoLPC/NGchh9+rWns5hurxEoHyltz8"

    deviceKey=$(bash "$BASE_DIR"/sha256/decrypt.sh "$encrypted_deviceKey")
    key=$(bash "$BASE_DIR"/sha256/decrypt.sh "$encrypted_key")
    iv=$(bash "$BASE_DIR"/sha256/decrypt.sh "$encrypted_iv")

    ciphertext=$(echo -n "$(printf '{"title": "%s", "body":"%s", "sound":"bell"}' "更新 openclash 第三方规则集结果" "$PUSH_MSG")" |
        openssl enc -aes-128-cbc -K "$(printf "$key" | xxd -ps -c 200)" -iv "$(printf "$iv" | xxd -ps -c 200)" | base64 -w 0)
    curl --data-urlencode "ciphertext=$ciphertext" --data-urlencode "iv=$iv" https://api.day.app/"$deviceKey" "$BASE_LOG_FILE" >>"$OPENCLASH_LOG_FILE" 2>&1
}

determine_the_ruleset_type() {
    local file_full_dir=$1
    local valid_line_count=$(awk '!/^[[:space:]]*(#|$)/ && !/payload:/ && NF > 0' "$file_full_dir" | wc -l)
    # 排除掉payload行、空白行、空字符串行、注释行之后剩余的行、且仅包含ip类型的行的数量
    local filtered_ip_line_count=$(awk '!/^[[:space:]]*(#|$)/ && !/payload:/ && NF > 0' "$file_full_dir" |
        grep -E -o "'?[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}'?" | wc -l)
    local ip_excluded_line_count=$((valid_line_count - filtered_ip_line_count))
    if [ $ip_excluded_line_count -eq 0 ]; then
        # 说明文件里面的有效行全是ip且是yaml类型的
        echo "ipcidr"
    elif [ $ip_excluded_line_count -eq $valid_line_count ]; then
        # 说明不存在ip类型，按 domain 类型处理
        # 由于部分domain规则包含正则表达式，为了提升网络响应速度，这里选择把所有规则行全部转换成 classical 类型
        echo "domain"
    elif [ $ip_excluded_line_count -gt 0 ]; then
        # 说明是ip和域名混合(或其它type混合)，按classical处理
        echo "classical"
    else
        echo "invalid"
    fi
}

common_rules_replace() {
    local file_full_dir=$1
    sed -i -e "s/'$//g" \
        -e "s/  - '+\./  - DOMAIN-SUFFIX,/g" \
        -e "s/  - '/  - DOMAIN,/g" \
        -e "s/  - 'SRC-IP-CIDR/  - SRC-IP-CIDR/g" \
        -e "s/  - 'IP-CIDR/  - IP-CIDR/g" \
        "$file_full_dir"
    sed -i -E '/^[[:space:]]*(#|$)/! {
            /^  - (IP-CIDR|SRC-IP-CIDR)/ {
                /,no-resolve$/! { s/$/,no-resolve/ }
            }
        }' "$file_full_dir"
}

ipcidr_rules_replace() {
    local file_full_dir=$1

    sed -i -e "s/'$//g" \
        -e "s/  - '/  - IP-CIDR,/g" \
        -e "s/  - 'SRC-IP-CIDR/  - SRC-IP-CIDR/g" \
        -e "s/  - 'IP-CIDR/  - IP-CIDR/g" \
        -e "s/'IP-CIDR/  - IP-CIDR/g" \
        -e "s/'SRC-IP-CIDR/  - SRC-IP-CIDR/g" \
        -e "/^  - IP-CIDR/! s/IP-CIDR/  - IP-CIDR/g" \
        -e "/^  - SRC-IP-CIDR/! s/SRC-IP-CIDR/  - SRC-IP-CIDR/g" \
        "$file_full_dir"

    sed -i -E '/^  - IP-CIDR/! { /\<([0-9]{1,3}\.){3}[0-9]{1,3}\>/ s/(.*)/  - IP-CIDR,\1/ }' "$file_full_dir"

    sed -i -E '/^[[:space:]]*(#|$)/! {
                /^  - (IP-CIDR|SRC-IP-CIDR)/ {
                    /,no-resolve$/! {
                        s/$/,no-resolve/
                    }
                }
            }' "$file_full_dir"
    # 追加 payload: 至顶部
    payload_count=$(awk '!/^[[:space:]]*(#|$)/ && /payload:/ && NF > 0' "$file_full_dir" | wc -l)
    if [ $payload_count -eq 0 ]; then
        payload="payload: "
        sed -i "1i$payload" "$file_full_dir" >/dev/null
    fi
}

is_ruleset_validate_yaml() {
    local file_name=$1
    local file_full_dir=$2
    local ruby_file="$BASE_SCRIPTS_DIR/validate_yaml.rb"

    ruby -e "
        require '$ruby_file';
        exit_code = 0;

        result1 = is_first_line_payload('$file_full_dir', '$BASE_LOG_FILE');
        exit_code = 1 if result1 == 1;
        result2 = is_validate_yaml('$file_full_dir', '$BASE_LOG_FILE');
        exit_code = 1 if result2 == 1;
        
        exit exit_code;
    "
    if [ ! $? -eq 0 ]; then
        logger "$file_name 文件格式校验失败，可能是下载时出了异常，跳过本规则集！"
        return 1
    fi
    return 0
}

exec_after_download() {
    local file_name=$1    # 文件名
    local download_dir=$2 # 临时下载路径
    local final_dir=$3    # 文件最终路径 $BASE_DIR

    local file_full_dir="$download_dir/$file_name"
    local lines_before_update
    lines_before_update=$(count_file_lines "$file_full_dir")

    # yaml 文件使用通用替换函数进行替换
    # 替换之后的 yaml behavior 就变成了 classical
    local is_valid_file=0
    # 保留注释行、空行、空字符串行和payload行，删除所有IPv6行
    sed -i '/^[[:space:]]*(#|$)/! { /^payload:/b; /:/d;}' "$file_full_dir" >/dev/null

    if [[ "$file_name" == *.yaml ]]; then
        common_rules_replace "$file_full_dir"
    else
        # 非 yaml 如 txt || list 等文件需要先确定规则集内容格式类型
        type=$(determine_the_ruleset_type "$file_full_dir")

        # 先把文件后缀名改成 .yaml
        file_name="${file_name%.*}.yaml"
        for t in "${RULESET_TYPES[@]}"; do
            if [ "$type" == "invalid" ]; then
                logger "Error: 文件 $file_name 格式无效，跳过它。请检查源链接是否正确 ==> $file_full_dir \n\n"
                is_valid_file=1
                break
            fi
            if [ "$type" == "ipcidr" ]; then
                ipcidr_rules_replace "$file_full_dir"
                break
            fi
            if [ "$type" == "$t" ]; then
                common_rules_replace "$file_full_dir"
                break
            fi
        done
    fi

    if [ $is_valid_file -eq 0 ]; then
        is_ruleset_validate_yaml "$file_name" "$file_full_dir"
        if [ $? -eq 1 ]; then
            rm "$file_full_dir" 2>/dev/null
        else
            mv "$file_full_dir" "$final_dir/$file_name" 2>/dev/null
            local lines_after_update
            lines_after_update=$(count_file_lines "$final_dir/$file_name")
            logger "$final_dir/$file_name 修改前一共 $lines_before_update 行内容， \
                修改后变为 $lines_after_update 行，总共删除了 $((lines_before_update - lines_after_update)) 行内容！\n\n"
        fi
    fi
}

update_crontab() {
    new_crontab_rules=(
        "*/1 * * * * cd $BASE_SCRIPTS_DIR && bash refresh_3rd_party_rules.sh 2>&1"
        "0 7 */2 * * cd $BASE_SCRIPTS_DIR && bash gen_3rd_party_rules.sh 2>&1"
    )

    # 提取新的Crontab任务中的命令部分
    for rule in "${new_crontab_rules[@]}"; do
        new_commands+=("$(echo "$rule" | awk '{$1=$2=$3=$4=$5=""; print $0}' | sed 's/^ //')")
    done

    # 创建临时文件来存放Crontab任务
    current_crontab_file=$(mktemp)
    updated_crontab_file=$(mktemp)

    # 获取当前的Crontab任务
    crontab -l >"$current_crontab_file"
    while IFS= read -r line; do
        # 提取当前任务的命令部分
        current_command=$(echo "$line" | awk '{$1=$2=$3=$4=$5=""; print $0}' | sed 's/^ //')
        match_found=false
        for command in "${new_commands[@]}"; do
            if [[ "$current_command" == "$command" ]]; then
                match_found=true
                logger "原有的定时任务 ==> $line 将被替换！"
                break
            fi
        done
        # 如果没有匹配到新的任务，则将该行保留
        if [ "$match_found" = false ]; then
            echo "$line" >>"$updated_crontab_file"
        fi
    done <"$current_crontab_file"

    for rule in "${new_crontab_rules[@]}"; do
        echo "$rule" >>"$updated_crontab_file"
    done

    # 安装更新后的Crontab任务
    crontab "$updated_crontab_file"
    rm -f "$current_crontab_file" "$updated_crontab_file"
}

append_err_msg() {
    file_index=$1
    aquire_lock
    if [ "$PUSH_MSG" == "$PUSH_MSG_INITIAL" ]; then
        PUSH_MSG=""
    fi
    PUSH_MSG+="$file_index, "
    release_lock
}

do_download() {
    local url=$1
    local file_dir=$2
    local file_full_dir=$3
    local file_name=$(basename "$url")
    curl -sS -o "$file_full_dir" "$url"
    exit_code=$?
    echo "$exit_code"

    # 备用多线程下载方案
    # if [ $exit_code -eq 0 ]; then
    #     logger "$file_name 已下载 ==> $TMP_RULESETS_FILE_DIRECTORY/$file_name"
    #     exec_after_download "$file_name" "$TMP_RULESETS_FILE_DIRECTORY" "$BASE_DIR"
    # else
    #     logger "Error: 【$file_name】下载失败！"
    #     append_err_msg "$file_name"
    # fi
}

download() {
    logger "准备下载第三方规则集文件..."
    if [ ! -d $TMP_RULESETS_FILE_DIRECTORY ]; then
        mkdir $TMP_RULESETS_FILE_DIRECTORY 2>/dev/null
    fi

    touch "$LOCK_FILE"
    # 尝试多线程下载，但机器性能太弱总报内存错误
    # local download_pids=()
    # local pid
    # for idx in "${!RULE_DOWNLOADING_URLS[@]}"; do
    #     url="${RULE_DOWNLOADING_URLS[$idx]}"
    #     file_name=$(basename "$url")
    #     file_full_dir="$TMP_RULESETS_FILE_DIRECTORY/$file_name"

    #     # 并发下载
    #     do_download "$url" "$TMP_RULESETS_FILE_DIRECTORY" "$file_full_dir" &
    #     pid=$!
    #     download_pids+=($pid)
    # done
    # for pid in "${download_pids[@]}"; do
    #     wait "$pid"
    # done

    local download_exit_code=0
    for idx in "${!RULE_DOWNLOADING_URLS[@]}"; do
        url="${RULE_DOWNLOADING_URLS[$idx]}"
        # 获得文件名
        file_name=$(basename "$url")
        file_full_dir="$TMP_RULESETS_FILE_DIRECTORY/$file_name"
        download_exit_code=$(do_download "$url" "$TMP_RULESETS_FILE_DIRECTORY" "$file_full_dir")
        if [ "$download_exit_code" -eq 0 ]; then
            logger "$file_name 已成功下载到本地 ==> $file_full_dir"
            exec_after_download "$file_name" "$TMP_RULESETS_FILE_DIRECTORY" "$BASE_DIR"
        else
            logger "Error: 【$file_name】下载失败！"
            append_err_msg "$file_name"
        fi
    done
    rm -rf "$TMP_RULESETS_FILE_DIRECTORY"
    rm -rf "$LOCK_FILE"
    if [ "$PUSH_MSG" != "$PUSH_MSG_INITIAL" ]; then
        PUSH_MSG+=" 下载失败，跳过更新\n"
    fi
    logger "第三方规则集文件下载、替换完成！"
}

entrance() {
    start_mills=$(current_millis)

    # 清空原来的日志文件内容
    flush_log
    # 下载第三方规则集文件至本地
    download
    # 更新自定义定时任务
    update_crontab

    end_mills=$(current_millis)
    duration=$((end_mills - start_mills))
    PUSH_MSG+=" 操作总耗时：$duration s."
    logger "所有操作总耗时 $duration s！"
    echo "所有操作总耗时 $duration s！"

    # 给手机发push
    do_push
}

if [ -z "$fake_generate" ]; then
    entrance
else
    # 裸连下载 github 规则集文件极大可能超时，导致服务启动时间过长或失败，所以改用异步下载
    # 先创建所需的 *.yaml 文件并追加假内容，等待服务正常启动之后再重新下载并刷新
    for url in "${URLS_TO_BE_REFRESHED[@]}"; do
        filtered_url="${url/${BASE_REFRESH_URL}/}"
        rm "$BASE_DIR"/"$filtered_url".yaml 2>/dev/null
        touch "$BASE_DIR"/"$filtered_url".yaml 2>/dev/null
        echo "payload:" >>"$BASE_DIR/$filtered_url.yaml"
        echo "  - DOMAIN-SUFFIX,XXXXXXXXXXXYYYYYYYYYYYZZZZZZ.com" >>"$BASE_DIR/$filtered_url.yaml"
    done
    start_time=$(date +%s)
    max_runtime=$((10 * 60))
    {
        while true; do
            # 检查是否超过最大运行时间
            current_time=$(date +%s)
            elapsed_time=$((current_time - start_time))
            if [ $elapsed_time -ge $max_runtime ]; then
                logger "Error: --------------- 异步下载任务达到最大运行时间 ($max_runtime s)，不再尝试 ---------------"
                break
            fi

            files_count=$(find -1 /tmp/yaml_* 2>/dev/null | wc -l)
            # 由于clash启动失败后也会删除上述文件，所以需要同时检测 clash core 以及 openclash_watchdog.sh 脚本是否已经正常加载并启动
            clash_core_started=$(pidof clash | sed 's/$//g' | wc -l 2>/dev/null)                     # /etc/init.d/openclash stop 函数
            watchdog_started=$(ps -efw | grep -v grep | grep -c "openclash_watchdog.sh" 2>/dev/null) # /usr/share/openclash/openclash_ps.sh unify_ps_status
            if [ "$files_count" -gt 0 ] || [ "$clash_core_started" -lt 1 ] || [ "$watchdog_started" -lt 1 ]; then
                logger "openclash 服务未完成启动，等待10秒后重试......"
                sleep 10
            else
                sleep 1
                entrance
                logger "自动下载第三方规则集任务完成，退出循环"
                break
            fi
        done
        exit 0
    } &
fi
