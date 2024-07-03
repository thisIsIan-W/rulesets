#!/bin/bash
BASE_DIR="/etc/openclash/rule_provider"
BASE_LOG_FILE="$BASE_DIR/download_and_refresh.log"

DEFAULT_RULE_DOWNLOADING_URL="https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release"
RULE_DOWNLOADING_BACKUP_URLS=(
    "https://testingcf.jsdelivr.net/gh/Loyalsoldier/clash-rules@release"
    "https://gcore.jsdelivr.net/gh/Loyalsoldier/clash-rules@release"
    "https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release"
    "https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release"
)

BASE_REFRESH_URL="http://127.0.0.1:9999/providers/rules/"
BASE_DASHBOARD_AUTH_TOKEN="Authorization: Bearer *@tRvj7oJys_fewqfcxWE32"
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
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >>$BASE_LOG_FILE
}
flush_log() {
    echo -n "" >$BASE_LOG_FILE
}