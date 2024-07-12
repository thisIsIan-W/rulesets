#!/bin/bash

BASE_DIR="/etc/openclash/rule_provider"
BASE_LOG_FILE="$BASE_DIR/rulesets_download_&_refresh.log"
OPENCLASH_LOG_FILE="/tmp/openclash.log"

IP_ADDR="$(uci -q get network.lan.ipaddr)"
CN_PORT="$(uci -q get openclash.config.cn_port)"
DASHBOARD_PASSWORD="$(uci -q get openclash.config.dashboard_password)"
BASE_REFRESH_URL="http://${IP_ADDR}:${CN_PORT}/providers/rules"
BASE_DASHBOARD_AUTH_TOKEN="Bearer ${DASHBOARD_PASSWORD}"

URLS_TO_BE_REFRESHED=(
  "$BASE_REFRESH_URL/my-proxy"
  "$BASE_REFRESH_URL/my-direct"
  "$BASE_REFRESH_URL/my-reject"
  "$BASE_REFRESH_URL/cncidr"
  "$BASE_REFRESH_URL/reject"
)

logger() {
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') $*" >>$BASE_LOG_FILE
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') $*" >>$OPENCLASH_LOG_FILE
}

refresh_config() {
    for index in "${!URLS_TO_BE_REFRESHED[@]}"; do
        ruby -e "require 'net/http'; \
         require 'uri'; \
         url = URI.parse('${URLS_TO_BE_REFRESHED[$index]}'); \
         http = Net::HTTP.new(url.host, url.port); \
         request = Net::HTTP::Put.new(url.path); \
         request['Content-Type'] = 'application/json'; \
         request['Authorization'] = '$BASE_DASHBOARD_AUTH_TOKEN'; \
         response = http.request(request); \
         puts ''
         if response.code == '204'; \
           exit 0; \
         else; \
           exit 1; \
         end"
        result=$?
        if [ $result -eq 0 ]; then
            logger "刷新配置 ${URLS_TO_BE_REFRESHED[$index]} 成功！"
        else
            logger "刷新配置 ${URLS_TO_BE_REFRESHED[$index]} 失败......"
        fi
    done
    logger ""
}

refresh_config