#!/bin/bash
# 以下配置写入：覆写设置 => 开发者选项 => exit 0 之前粘贴以下两行：
# 需要先把脚本文件保存在 /etc/openclash/rule_provider/scripts/ 文件夹下，并先执行 update_rules.sh 脚本(需要先连接上代理)
# RUBY_FILE="/etc/openclash/rule_provider/scripts/custom_rules.rb"
# /usr/bin/ruby -e "require '$RUBY_FILE'; write_custom_rules('$CONFIG_FILE', '$LOG_FILE')"

BASE_DIR="/etc/openclash/rule_provider"
BASE_SCRIPTS_DIR="/etc/openclash/rule_provider/scripts"
BASE_LOG_FILE="/etc/openclash/rule_provider/update_rules.log"
OPENCLASH_LOG_FILE="/tmp/openclash.log"

RULE_DOWNLOADING_URLS=(
    "https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release"
    "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release"
    "https://testingcf.jsdelivr.net/gh/Loyalsoldier/clash-rules@release"
    "https://gcore.jsdelivr.net/gh/Loyalsoldier/clash-rules@release"
    "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release"
)
FILES=(
    # 如果需要新增，先在此处新增，然后到 refresh_rules.sh 的 URLS_TO_BE_REFRESHED 数组里再次按格式新增
    "telegramcidr.txt"
    "cncidr.txt"
    "direct.txt"
    "reject.txt"
)
MY_RULE_DOWNLOADING_URLS=(
    "https://raw.githubusercontent.com/thisIsIan-W/rulesets/main/configs"
    "https://fastly.jsdelivr.net/gh/thisIsIan-W/rulesets@release/configs"
    "https://testingcf.jsdelivr.net/gh/thisIsIan-W/rulesets@release/configs"
    "https://gcore.jsdelivr.net/gh/thisIsIan-W/rulesets@release/configs"
    "https://cdn.jsdelivr.net/gh/thisIsIan-W/rulesets@release/configs"
)
MY_FILES=(
    # 注意与上面 FILES 后缀的区别
    # 如果需要新增，先在此处新增，然后到 refresh_rules.sh 的 URLS_TO_BE_REFRESHED 数组里再次按格式新增
    "my-direct.yaml"
    "my-proxy.yaml"
    "my-reject.yaml"
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

PUSH_MSG="全部第三方规则集文件更新成功！"
PUSH_MSG_INITAIL="$PUSH_MSG"

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
    curl --data-urlencode "ciphertext=$ciphertext" --data-urlencode "iv=$iv" https://api.day.app/$deviceKey
}

exec_after_download() {
    local current_target_name=$1
    local current_file_path=$2
    local lines_before_update=$(count_file_lines "$current_file_path")
    if echo "$current_target_name" | grep -q "cidr"; then
        sed -i '1b; /:/d' "$current_file_path"
        logger "删除 $current_file_path 中带冒号的IPv6行成功！"
    else
        sed -i "s/'$//g" "$current_file_path"
        logger "删除 $current_file_path 中行尾的单引号 成功！"

        sed -i "s/  - '+\./  - DOMAIN-SUFFIX,/g" "$current_file_path"
        logger "替换 $current_file_path 中的 \"  - '+.\" 为 \"  - DOMAIN-SUFFIX,\" 成功！"

        sed -i "s/  - '/  - DOMAIN-SUFFIX,/g" "$current_file_path"
        logger "替换 $current_file_path 中的 \"- '\" 为 \"  - DOMAIN-SUFFIX,\" 成功！"
    fi

    local lines_after_update=$(count_file_lines "$current_file_path")
    logger "$current_target_name 修改前一共 $lines_before_update 行内容，修改后变为 $lines_after_update 行，总共删除了 $((lines_before_update - lines_after_update)) 行内容！\n\n"
}

update_crontab() {
    # 要检查和添加的 crontab 配置项数组
    entries=(
        "*/5 * * * * cd $BASE_SCRIPTS_DIR && bash refresh_rules.sh 2>&1"
        "*/20 * * * * cd $BASE_SCRIPTS_DIR && bash update_rules.sh 2>&1"
    )

    # 获取当前用户的 crontab
    current_crontab=$(crontab -l 2>/dev/null)
    update_required=false
    for entry in "${entries[@]}"; do
        if echo "$current_crontab" | grep -Fxq "$entry"; then
            echo ""
        else
            current_crontab="$current_crontab"$'\n'"$entry"
            update_required=true
        fi
    done
    if [ "$update_required" = true ]; then
        # 非交互方式更新 crontab
        echo "$current_crontab" | crontab -
    fi
}

append_err_msg() {
    file_index=$1
    if [ "$PUSH_MSG" == "$PUSH_MSG_INITAIL" ]; then
        PUSH_MSG=""
    fi
    PUSH_MSG+="$file_index, "
}

do_download() {
    local cur_url_to_download=$1
    local cur_file_to_download=$2
    local my=$3
    local cur_download_url="$cur_url_to_download/$cur_file_to_download"
    local cur_target_name=$cur_file_to_download
    if [ -z "$my" ]; then
        cur_target_name="${cur_file_to_download%.txt}.yaml"
    fi
    local cur_file_path="$BASE_DIR/$cur_target_name"

    logger "准备从 $cur_download_url 下载到 $cur_file_path ..."

    curl --retry 0 --connect-timeout 3 -sS -o "$cur_file_path" "$cur_download_url"
    local download_exit_code=$?
    if [ ! $download_exit_code -eq 0 ]; then
        logger "Error: ------URL: $cur_download_url 下载失败"
    fi
    echo $download_exit_code
}

download() {
    logger "准备下载第三方规则集文件..."

    # shell 推荐 声明 和 赋值 分开写以避免潜在的不必要的问题
    # 下载并重命名文件
    local exec_result=0
    local download_exit_code=0
    local retry_count=0
    for index in "${!FILES[@]}"; do
        for idx in "${!RULE_DOWNLOADING_URLS[@]}"; do
            current_file_name="${FILES[$index]}"
            download_exit_code=$(do_download "${RULE_DOWNLOADING_URLS[$idx]}" "$current_file_name")
            if [ $download_exit_code -eq 0 ]; then
                ruby $BASE_SCRIPTS_DIR/validate_yaml.rb "$BASE_DIR/${current_file_name%.txt}.yaml" "$BASE_LOG_FILE"
                if [ ! $? -eq 0 ]; then
                    rm "$BASE_DIR/${current_file_name%.txt}.yaml"
                    logger "$current_target_name 文件格式校验失败，可能是下载时出了异常，准备重新下载！"
                    retry_count+=1
                    continue
                fi

                logger "${RULE_DOWNLOADING_URLS[$idx]}/${FILES[$index]} 已成功下载到本地！"
                retry_count=0
                break
            fi
            retry_count+=1
        done

        if [ $retry_count -eq 0 ]; then
            exec_after_download "${FILES[$index]%.txt}.yaml" "$BASE_DIR/${FILES[$index]%.txt}.yaml"
        else
            logger "Error: -----------------------------: 文件 ${FILES[$index]} 所有链接全部重试完成但依旧下载失败，跳过它......\n\n\n\n"
            append_err_msg "${FILES[$index]}"
        fi
    done

    retry_count=0

    for i in "${!MY_FILES[@]}"; do
        for ix in "${!MY_RULE_DOWNLOADING_URLS[@]}"; do
            download_exit_code=$(do_download "${MY_RULE_DOWNLOADING_URLS[$ix]}" "${MY_FILES[$i]}" "my")
            if [ $download_exit_code -eq 0 ]; then

                ruby $BASE_SCRIPTS_DIR/validate_yaml.rb "$BASE_DIR/${MY_FILES[$i]}" "$BASE_LOG_FILE"
                if [ ! $? -eq 0 ]; then
                    rm "$BASE_DIR/${MY_FILES[$i]}"
                    logger "$BASE_DIR/${MY_FILES[$i]} 文件格式校验失败，可能是下载时出了异常，准备重新下载！"
                    retry_count+=1
                    continue
                fi

                logger "${MY_RULE_DOWNLOADING_URLS[$ix]}/${MY_FILES[$i]} 已成功下载到本地！\n"
                retry_count=0
                break
            fi
            retry_count+=1
        done

        if [ ! $retry_count -eq 0 ]; then
            logger "Error: -----------------------------: 文件 ${MY_FILES[$i]} 所有链接全部重试完成但依旧下载失败，跳过它......\n\n\n\n"
            append_err_msg "${MY_FILES[$i]}"
        fi
    done

    logger "第三方规则集文件下载成功！"
}

entrance() {
    start_mills=$(current_millis)

    flush_log
    update_crontab

    download

    if [ "$PUSH_MSG" != "$PUSH_MSG_INITAIL" ]; then
        PUSH_MSG+=" 下载失败，跳过更新\n"
    fi

    bash $BASE_SCRIPTS_DIR/refresh_rules.sh

    end_mills=$(current_millis)
    duration=$((end_mills - start_mills))
    PUSH_MSG+=" 操作总耗时：$duration s."
    logger "所有操作总耗时 $duration s！"

    do_push
}

# 入口函数
entrance
