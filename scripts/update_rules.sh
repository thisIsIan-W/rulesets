#!/bin/bash
. /etc/openclash/rule_provider/base.sh
. /etc/openclash/rule_provider/refresh_rules.sh
. /etc/openclash/rule_provider/bark.sh

## FILES 和 TARGET_NAMES 的文件名称顺序必须一一对应！
FILES=(
    "telegramcidr.txt"
    "cncidr.txt"
    "direct.txt"
)
TARGET_NAMES=(
    "telegramcidr.yaml"
    "cncidr.yaml"
    "direct.yaml"
)

PUSH_MSG="全部第三方规则集文件更新成功！"
PUSH_MSG_INITAIL="$PUSH_MSG"

current_millis() {
    # iStoreOS 上的时间戳计算方式与普通linux发行版不一样
    echo $(($(date +%s%3N)))
}

do_push() {
    if [ "$PUSH_MSG" != "$PUSH_MSG_INITAIL" ]; then
        PUSH_MSG+=" 下载失败，跳过更新\n"
    fi
    PUSH_MSG+=" 操作总耗时：$duration s."
    push_notification "更新 openclash 第三方规则集结果" "$PUSH_MSG"
}

do_download() {
    logger "开始下载: $2 -> $1"

    local download_exit_code=0
    local yaml_valid_exit_code=0
    curl --retry 0 --connect-timeout 3 -sS -o "$1" "$2"
    return $?
}

exec_after_download() {
    local current_url=$1
    local current_target_name=$2
    local current_file_path=$3

    logger "文件 $current_url 下载成功，并重命名为 $current_target_name."

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
    logger "$current_target_name 修改前一共 $lines_before_update 行内容，修改后变为 $lines_after_update 行，总共删除了 $((lines_before_update - lines_after_update)) 行内容！"
}

retry_different_urls() {
    local cur_file_to_download=$1
    local retry_count=0

    # ${!FILES[@]} 遍历的是索引，可以使用 $index 来获取当前遍历到的索引
    # ${FILES[@]}  遍历的是元素，无法获取索引
    local index
    local cur_download_url
    local cur_target_name
    local cur_file_path
    for index in "${!RULE_DOWNLOADING_BACKUP_URLS[@]}"; do
        cur_download_url="${RULE_DOWNLOADING_BACKUP_URLS[$index]}/$cur_file_to_download"
        logger "重试下载的 URL 为：$cur_download_url"

        cur_target_name="${cur_file_to_download%.txt}.yaml"
        cur_file_path="$BASE_DIR/$cur_target_name"

        do_download "$cur_file_path" "$cur_download_url"
        download_exit_code=$?
        if [ $download_exit_code -eq 0 ]; then
            retry_count=0
            break
        fi

        logger "Error: ------重试地址: $cur_download_url 下载失败，换下一个URL再次重试！！！\n"
        openclash_logger "Error: ------重试地址: $cur_download_url 下载失败，换下一个URL再次重试！！！"
        retry_count=1
    done
    logger ""
    return "$retry_count"
}

download() {
    start_mills=$(current_millis)
    # shell 推荐 声明 和 赋值 分开写以避免潜在的不必要的问题
    # 下载并重命名文件
    local index
    local url
    local target_name
    local file_path
    local exec_result=0
    for index in "${!FILES[@]}"; do
        url="$DEFAULT_RULE_DOWNLOADING_URL/${FILES[$index]}"
        logger "第一次尝试下载文件：$url"

        target_name="${TARGET_NAMES[$index]}"
        file_path="$BASE_DIR/$target_name"

        do_download "$file_path" "$url"
        download_code=$?
        if [ $download_code -ne 0 ]; then
            logger "文件从 $url 镜像下载失败，准备从其它 URL 重试......\n"
            retry_different_urls "${FILES[$index]}"
            exec_result=$?
        fi

        if [ $exec_result -eq 0 ]; then
            exec_after_download "$url" "$target_name" "$file_path"
        else
            logger "Error: -----------------------------: 文件 ${FILES[$index]} 所有链接全部重试完成但依旧下载失败，跳过它......\n\n\n\n"
            openclash_logger "Error: -----------------------------: 文件 ${FILES[$index]} 所有链接全部重试完成但依旧下载失败，跳过它......"
            if [ "$PUSH_MSG" == "$PUSH_MSG_INITAIL" ]; then
                PUSH_MSG=""
            fi
            PUSH_MSG+="${FILES[$index]}, "
        fi
    done


    refresh_manually
    do_push

    logger "\n\n"

    end_mills=$(current_millis)
    duration=$((end_mills - start_mills))
    logger "所有操作总耗时 $duration s！"
}

flush_log

logger "准备下载第三方规则集文件..."
download
logger "第三方规则集文件下载成功！"

logger " 刷新所有自定义配置结束！"