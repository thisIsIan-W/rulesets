#!/bin/bash
BASE_DIR="/etc/openclash/rule_provider"
BASE_LOG_FILE="/tmp/openclash.log"

DEFAULT_RULE_DOWNLOADING_URL="https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release"
RULE_DOWNLOADING_BACKUP_URLS=(
    ## 这里面的规则会有12个小时的延迟，留作备用
    "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release"
    "https://testingcf.jsdelivr.net/gh/Loyalsoldier/clash-rules@release"
    "https://gcore.jsdelivr.net/gh/Loyalsoldier/clash-rules@release"
    "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release"
)
MY_RULE_DOWNLOADING_URLS=(
  "https://raw.githubusercontent.com/thisIsIan-W/rulesets/main/configs"
  "https://fastly.jsdelivr.net/gh/thisIsIan-W/rulesets@release/configs"
  "https://testingcf.jsdelivr.net/gh/thisIsIan-W/rulesets@release/configs"
  "https://gcore.jsdelivr.net/gh/thisIsIan-W/rulesets@release/configs"
  "https://cdn.jsdelivr.net/gh/thisIsIan-W/rulesets@release/configs"
)

BASE_REFRESH_URL="http://127.0.0.1:$(uci -q get openclash.config.cn_port)/providers/rules/"
BASE_DASHBOARD_AUTH_TOKEN="Authorization: Bearer $(uci -q get openclash.config.dashboard_password)"
URLS_TO_BE_REFRESHED=(
    "${BASE_REFRESH_URL}telegramcidr"
    "${BASE_REFRESH_URL}cncidr"
    "${BASE_REFRESH_URL}direct"
    "${BASE_REFRESH_URL}my-proxy"
    "${BASE_REFRESH_URL}my-direct"
    "${BASE_REFRESH_URL}my-reject"
)

count_file_lines() {
    cat $1 | wc -l
}
logger() {
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') $*" >>$BASE_LOG_FILE
}
flush_log() {
    echo -n "" >$BASE_LOG_FILE
}