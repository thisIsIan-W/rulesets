#!/bin/bash
BASE_LOG_FILE="/etc/openclash/rule_provider/update_rules.log"
OPENCLASH_LOG_FILE="/tmp/openclash.log"
BASE_REFRESH_URL="http://127.0.0.1:$(uci -q get openclash.config.cn_port)/providers/rules/"
BASE_DASHBOARD_AUTH_TOKEN="Authorization: Bearer $(uci -q get openclash.config.dashboard_password)"
URLS_TO_BE_REFRESHED=(
  # 此处内容需要与 update_rules.sh 文件中的 FILES 和 MY_FILES 数组一一对应，否则配置无法刷新！
  "${BASE_REFRESH_URL}telegramcidr"
  "${BASE_REFRESH_URL}cncidr"
  "${BASE_REFRESH_URL}reject"
  "${BASE_REFRESH_URL}my-proxy"
  "${BASE_REFRESH_URL}my-direct"
  "${BASE_REFRESH_URL}my-reject"
)

logger() {
  echo -e "$(date +'%Y-%m-%d %H:%M:%S') $*" >>$BASE_LOG_FILE
  echo -e "$(date +'%Y-%m-%d %H:%M:%S') $*" >>$OPENCLASH_LOG_FILE
}

do_refresh() {
  curl -sS --retry 0 --location --request PUT "${BASE_REFRESH_URL}" --header "$BASE_DASHBOARD_AUTH_TOKEN"
  result=$?
  if [ $result -eq 0 ]; then
    logger "刷新配置 $1 成功！"
  else
    logger "刷新配置 $1 失败......"
  fi
}

refresh_manually() {
  for index in "${!URLS_TO_BE_REFRESHED[@]}"; do
    do_refresh "${URLS_TO_BE_REFRESHED[$index]}" "${URLS_TO_BE_REFRESHED[$index]}"
  done
}

refresh_manually
