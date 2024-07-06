#!/bin/bash
# 以下配置写入：覆写设置 => 开发者选项 => exit 0 之前粘贴以下两行：
# 需要先把脚本文件保存在 /etc/openclash/rule_provider/scripts/ 文件夹下，并先执行 import_3rd_party_rules.sh 脚本(需要先连接上代理)
# RUBY_FILE="/etc/openclash/rule_provider/scripts/custom_rules.rb"
# /usr/bin/ruby -e "require '$RUBY_FILE'; write_custom_rules('$CONFIG_FILE', '$LOG_FILE')"

BASE_SCRIPTS_DIR="/etc/openclash/rule_provider/scripts"
BASE_LOG_FILE="/etc/openclash/rule_provider/import_3rd_party_rules.log"

. /etc/openclash/rule_provider/scripts/3rd_party_rules_utils.sh "$BASE_SCRIPTS_DIR" "$BASE_LOG_FILE"

BASE_DIR="/etc/openclash/rule_provider"
TMP_RULESETS_FILE_DIRECTORY="$BASE_DIR/tmp"
OPENCLASH_LOG_FILE="/tmp/openclash.log"
PUSH_MSG="全部第三方规则集文件更新成功！"
PUSH_MSG_INITAIL="$PUSH_MSG"

RULE_DOWNLOADING_URLS=(
    "https://raw.githubusercontent.com/thisIsIan-W/rulesets/main/configs/my-direct.yaml"
    "https://raw.githubusercontent.com/thisIsIan-W/rulesets/main/configs/my-proxy.yaml"
    "https://raw.githubusercontent.com/thisIsIan-W/rulesets/main/configs/my-reject.yaml"
    "https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/ChinaIPs/ChinaIPs_IP.txt"
    # "https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/cncidr.txt"
    # "https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/ChinaIPs/ChinaIPs_Classical_No_IPv6.yaml"
    # "https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/ChinaIPs/ChinaIPs.list"
    # "https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/gfw.txt"
    # "https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/applications.txt"
    # "https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/telegramcidr.txt"
    # "https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/proxy.txt"
)
RULESET_TYPES=(
    "ipcidr"
    "classical"
    "domain"
    "invalid"
)

count_file_lines() {
    cat $1 | wc -l
}
logger() {
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') $*" >>$BASE_LOG_FILE
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') $*" >>$OPENCLASH_LOG_FILE
}
flush_log() {
    echo -n "" >$BASE_LOG_FILE
}
current_millis() {
    echo $(($(date +%s%3N)))
}

do_push() {
    # Documentation: https://bark.day.app/#/encryption
    encrypted_deviceKey="U2FsdGVkX1/4ZpX7VeztU6fOabZXhrNFkHi4yNuUjxiHHru+R657NEPADRDa7lPf"
    encrypted_key="U2FsdGVkX1+ttdUfGCkXwORU5q1vCjWO1+QwvXCus8eo0RbBCKKWccuNtC3S0TbZ"
    encrypted_iv="U2FsdGVkX1/lduGY4+8UlBZ0qU1Augum43sd3NIMq52YzkIWFtqDyUhZrpDWvE7h"

    deviceKey=$(bash /etc/openclash/rule_provider/sha256/decrypt.sh $encrypted_deviceKey)
    key=$(bash /etc/openclash/rule_provider/sha256/decrypt.sh $encrypted_key)
    iv=$(bash /etc/openclash/rule_provider/sha256/decrypt.sh $encrypted_iv)

    ciphertext=$(echo -n $(printf '{"title": "%s", "body":"%s", "sound":"bell"}' "更新 openclash 第三方规则集结果" "$PUSH_MSG") |
        openssl enc -aes-128-cbc -K $(printf $key | xxd -ps -c 200) -iv $(printf $iv | xxd -ps -c 200) | base64 -w 0)
    curl --data-urlencode "ciphertext=$ciphertext" --data-urlencode "iv=$iv" https://api.day.app/$deviceKey $OPENCLASH_LOG_FILE >>$BASE_LOG_FILE 2>&1
}

exec_after_download() {
    local file_name=$1    # 文件名
    local download_dir=$2 # 临时下载路径
    local final_dir=$3    # 文件最终路径 $BASE_DIR

    local file_full_dir="$download_dir/$file_name"
    local lines_before_update=$(count_file_lines "$file_full_dir")

    # yaml 文件使用通用替换函数进行替换
    local is_valid_file=0
    if [ "$file_name" == *.yaml ]; then
        common_rules_replace "$file_full_dir"
    else
        # 非 yaml 如 txt || list 等文件需要先确定规则集类型
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
            local lines_after_update=$(count_file_lines "$final_dir/$file_name")
            logger "$final_dir/$file_name 修改前一共 $lines_before_update 行内容，修改后变为 $lines_after_update 行，总共删除了 $((lines_before_update - lines_after_update)) 行内容！\n\n"
        fi
    fi
}

update_crontab() {
    new_crontab_rules=(
        "*/10 * * * * cd $BASE_SCRIPTS_DIR && bash refresh_3rd_party_rules.sh 2>&1"
        "0 7 * * * cd $BASE_SCRIPTS_DIR && bash import_3rd_party_rules.sh 2>&1"
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

    logger "新的Crontab任务列表 ==> \n\n$(crontab -l)\n\n"

    rm -f "$current_crontab_file" "$updated_crontab_file"
}

append_err_msg() {
    file_index=$1
    if [ "$PUSH_MSG" == "$PUSH_MSG_INITAIL" ]; then
        PUSH_MSG=""
    fi
    PUSH_MSG+="$file_index, "
}

do_download() {
    local url=$1
    local file_dir=$2
    local file_full_dir=$3
    if [ ! -d $file_dir ]; then
        mkdir $file_dir 2>/dev/null
    fi

    logger "准备开始下载. 保存路径为：$file_full_dir, 下载链接为： $url"
    curl -sS -o "$file_full_dir" "$url"
    exit_code=$?
    if [ ! $exit_code -eq 0 ]; then
        logger "Error: ------URL: $url 下载失败, exit_code=$exit_code"
    fi
    echo $exit_code
}

download() {
    logger "准备下载第三方规则集文件..."
    local exec_result=0
    local download_exit_code=0
    for idx in "${!RULE_DOWNLOADING_URLS[@]}"; do
        url="${RULE_DOWNLOADING_URLS[$idx]}"
        # 获得文件名
        file_name=$(basename "$url")
        file_full_dir="$TMP_RULESETS_FILE_DIRECTORY/$file_name"
        download_exit_code=$(do_download "$url" "$TMP_RULESETS_FILE_DIRECTORY" "$file_full_dir")
        if [ $download_exit_code -eq 0 ]; then
            logger "$file_name 已成功下载到本地 ==> $file_full_dir"
            exec_after_download "$file_name" "$TMP_RULESETS_FILE_DIRECTORY" "$BASE_DIR"
        else
            logger "Error: 【$file_name】下载失败！"
            append_err_msg "$file_name"
        fi
    done

    rm -rf "$TMP_RULESETS_FILE_DIRECTORY"

    logger "第三方规则集文件下载、替换完成！"
}

entrance() {
    start_mills=$(current_millis)

    flush_log
    update_crontab

    download

    if [ "$PUSH_MSG" != "$PUSH_MSG_INITAIL" ]; then
        PUSH_MSG+=" 下载失败，跳过更新\n"
    fi

    bash $BASE_SCRIPTS_DIR/refresh_3rd_party_rules.sh

    end_mills=$(current_millis)
    duration=$((end_mills - start_mills))
    PUSH_MSG+=" 操作总耗时：$duration s."
    logger "所有操作总耗时 $duration s！"

    do_push
}

# 入口函数
entrance
