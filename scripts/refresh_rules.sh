#!/bin/bash
. $PWD/base.sh

do_refresh() {
  curl -sS --retry 0 --location --request PUT "${BASE_REFRESH_URL}" --header "$BASE_DASHBOARD_AUTH_TOKEN"
  result=$?
  if [ $result -eq 0 ]; then
    logger "刷新配置 $1 成功！"
  else
    logger "刷新配置 $1 失败......"
  fi
}

# 自动刷新配置的时间间隔为 1分钟
refresh_manually() {
  logger "自动刷新配置开始..."
  
  for index in "${!URLS_TO_BE_REFRESHED[@]}"; do
    do_refresh "${URLS_TO_BE_REFRESHED[$index]}" "${URLS_TO_BE_REFRESHED[$index]}"
  done
  
  logger "自动刷新配置结束...\n\n\n"
}

# 不为空才说明命令是从 update_rules 发来的，这里不取反
if [ -z "$1" ]; then
  refresh_manually
fi