#!/bin/bash

# 本脚本用于下载自定义及第三方规则集

OPENCLASH_LOGFILE=$1
SCRIPTS_DOWNLOADING_BACKUP_URLS=(
    "https://raw.githubusercontent.com/thisIsIan-W/rulesets/release/scripts"
    "https://testingcf.jsdelivr.net/gh/thisIsIan-W/rulesets@release/scripts"
    "https://fastly.jsdelivr.net/gh/thisIsIan-W/rulesets@release/scripts"
    "https://gcore.jsdelivr.net/gh/thisIsIan-W/rulesets@release/scripts"
    "https://cdn.jsdelivr.net/gh/thisIsIan-W/rulesets@release/scripts"
)
SCRIPT_NAMES=(
    "base.sh"
    "bark.sh"
    "update_rules.sh"
    "refresh_rules.sh"
)
SCRIPTS_DOWNLOAD_DIR="/etc/openclash/rule_provider"

scripts_log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >>$OPENCLASH_LOGFILE
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
            scripts_log "Error: 从 $script_name 尝试从所有CDN下载失败，不再继续下载及执行后续自定义逻辑......"
            exit
        else
            chmod +x $download_dir
            download_count=1
        fi
    done

    # 全部下载成功，加入到cron脚本中
    echo "*/5 * * * * cd /etc/openclash/rule_provider && bash refresh_rules.sh 2>&1" >> /etc/crontabs/root
    echo "0 3 * * * cd /etc/openclash/rule_provider && bash update_rules.sh 2>&1" >> /etc/crontabs/root

    # 执行后续逻辑
    bash $SCRIPTS_DOWNLOAD_DIR/update_rules.sh
}

download_extra_scripts_from_cdns