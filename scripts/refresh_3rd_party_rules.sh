#!/bin/bash
shell_cfg_path=$1
if [ -z "$shell_cfg_path" ]; then
  shell_cfg_path="/etc/openclash/rule_provider/scripts/common/rule_provider_urls_cfg.sh"
fi
. $shell_cfg_path

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
         request['Content-Type'] = 'application/json' \
         request['Authorization'] = '$BASE_DASHBOARD_AUTH_TOKEN' \
         response = http.request(request); \
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