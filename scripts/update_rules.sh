#!/bin/bash
. $PWD/base.sh
. $PWD/refresh_rules.sh
. $PWD/bark.sh

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

# 清空之前的日志
flush_log

current_millis() {
    # iStoreOS 上的时间戳计算方式与普通linux发行版不一样
    echo $(($(date +%s%3N)))
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

    do_refresh "${current_target_name%.*}"
    do_push

    logger "\n\n"
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

        logger "Error: ------重试地址: $cur_download_url 还是下载失败，换下一个URL再次重试！！！\n"
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
            if [ "$PUSH_MSG" == "$PUSH_MSG_INITAIL" ]; then
                PUSH_MSG=""
            fi
            PUSH_MSG+="${FILES[$index]}, "
        fi
    done

    end_mills=$(current_millis)
    duration=$((end_mills - start_mills))
    logger "所有操作总耗时 $duration s！"
}

do_push() {
    if [ "$PUSH_MSG" != "$PUSH_MSG_INITAIL" ]; then
        PUSH_MSG+=" 下载失败，跳过更新\n"
    fi
    PUSH_MSG+=" 操作总耗时：$duration s."

    local bark_secrets_file="$SCRIPTS_DOWNLOAD_DIR/bark_secrets.txt"
    local deviceKey
    local key
    local iv
    if [ ! -f "$bark_secrets_file" ]; then
        logger "Warning: 请在 $SCRIPTS_DOWNLOAD_DIR 目录下定义 bark_secrets.txt 并参考 https://bark.day.app/#/encryption 分别以新行指定 deviceKey=?、key=?、iv=? 三个参数，否则推送将不生效！"
        exit
    else
        # 声明关联数组（哈希表）
        declare -A hash

        while IFS='=' read -r key value; do
            # 跳过空行和以 # 开头的注释行
            if [[ -n "$key" && ! "$key" =~ ^\s*# ]]; then
                # 去除行末的换行符
                value="${value%"${value##*[![:space:]]}"}"
                hash["$key"]="$value"
            fi
        done < "$bark_secrets_file"

        deviceKey=${hash["deviceKey"]}
        key=${hash["key"]}
        iv=${hash["iv"]}
        if [ -z "${deviceKey}" ] || [ -z "${key}" ] || [ -z "${iv}" ]; then
            logger "Warning: 请在 $SCRIPTS_DOWNLOAD_DIR 目录下定义 bark_secrets.txt 并参考 https://bark.day.app/#/encryption 分别以新行指定 deviceKey=?、key=?、iv=? 三个参数，否则推送将不生效！"
            exit
        fi
    fi
    push_notification "更新 openclash 第三方规则集结果" "$PUSH_MSG" "$deviceKey" "$key" "$iv"
}

download

logger " 刷新所有自定义配置结束！"