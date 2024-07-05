#!/bin/bash

# 本脚本用于下载自定义及第三方规则集
BASE_DIR="/etc/openclash/rule_provider"
BASE_LOG_FILE="/etc/openclash/rule_provider/update_rules.log"
OPENCLASH_LOG_FILE="/tmp/openclash.log"
SCRIPTS_DOWNLOADING_BACKUP_URLS=(
    "https://gitee.com/ian-w/xyz-toss/raw/master/scripts"
)
SCRIPT_NAMES=(
    "update_rules.sh"
    "refresh_rules.sh"
)
SCRIPTS_DOWNLOAD_DIR="/etc/openclash/rule_provider/scripts"

scripts_log() {
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') $*" >>$BASE_LOG_FILE
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') $*" >>$OPENCLASH_LOG_FILE
}

update_crontab() {
    # 要检查和添加的 crontab 配置项数组
    entries=(
        "*/5 * * * * cd /etc/openclash/rule_provider/scripts && bash refresh_rules.sh 2>&1"
        "*/1 * * * * cd /etc/openclash/rule_provider/scripts && bash update_rules.sh 2>&1"
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

download_extra_scripts_from_cdns() {
    local download_url
    local download_dir
    local download_exit_code
    local download_count=0
    local cdn_count=${#SCRIPTS_DOWNLOADING_BACKUP_URLS[*]}
    local script_name

    for script_index in "${!SCRIPT_NAMES[@]}"; do
        script_name="${SCRIPT_NAMES[$script_index]}"
        download_count=0

        for index in "${!SCRIPTS_DOWNLOADING_BACKUP_URLS[@]}"; do
            download_url="${SCRIPTS_DOWNLOADING_BACKUP_URLS[$index]}/$script_name"
            download_dir="$SCRIPTS_DOWNLOAD_DIR/$script_name"

            curl -sS -o "$download_dir" "$download_url"
            download_exit_code=$?
            if [ $download_exit_code -eq 0 ]; then
                break
            fi

            scripts_log "Error: 从 ${SCRIPTS_DOWNLOADING_BACKUP_URLS[$index]} 下载 $script_name 失败，准备尝试下一个CDN......"
            download_count=$((download_count + 1))
        done

        if [ $download_count -eq $cdn_count ]; then
            scripts_log "Error: $script_name 尝试从所有CDN下载失败，不再继续下载及执行后续自定义逻辑......"
            exit
        else
            scripts_log "$script_name 下载成功！"
            chmod +x $download_dir 2>/dev/null
        fi
    done

    update_crontab
}

download_extra_scripts_from_cdns
