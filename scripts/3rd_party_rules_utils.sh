#!/bin/bash
SCRIPTS_DIR=$1
LOG_FILE=$2

determine_the_ruleset_type() {
    local file_full_dir=$1
    # 保留注释行、空行、空字符串行和payload行，删除所有IPv6行
    sed -i '/^[[:space:]]*(#|$)/! { /^payload:/b; /:/d;}' "$file_full_dir" >/dev/null
    logger "删除 $file_full_dir 中的IPv6行成功！"

    local valid_line_count=$(awk '!/^[[:space:]]*(#|$)/ && !/payload:/ && NF > 0' "$file_full_dir" | wc -l)
    # 排除掉payload行、空白行、空字符串行、注释行之后剩余的行、且仅包含ip类型的行的数量
    local filtered_ip_line_count=$(awk '!/^[[:space:]]*(#|$)/ && !/payload:/ && NF > 0' "$file_full_dir" | grep -E -o "'?[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}'?" | wc -l)
    local ip_excluded_line_count=$((valid_line_count - filtered_ip_line_count))
    if [ $ip_excluded_line_count -eq 0 ]; then
        # 说明文件里面的有效行全是ip，按ipcidr类型处理
        logger "文件 $file_full_dir 中【只包含ip类型】的行，按 ipcidr 处理......"
        echo "ipcidr"
    elif [ $ip_excluded_line_count -eq $valid_line_count ]; then
        # 说明不存在ip类型，按 domain 类型处理
        logger "文件 $file_full_dir 中【不包含ip类型】的行，按 domain 处理......"
        echo "domain"
    elif [ $ip_excluded_line_count -gt 0 ]; then
        # 说明是ip和域名混合(或其它type混合)，按classical处理
        logger "文件 $file_full_dir 中【包含ip和其它类型】的行，按 classical 处理......"
        echo "classical"
    else
        echo "invalid"
    fi
}

common_rules_replace() {
    local file_full_dir=$1
    sed -i "s/'$//g" "$file_full_dir" >/dev/null
    logger "删除 $file_full_dir 中行尾的单引号成功！"

    sed -i -e "s/  - '+\./  - DOMAIN-SUFFIX,/g" \
        -e "s/  - '/  - DOMAIN,/g" \
        "$file_full_dir" >/dev/null
    logger "替换 $file_full_dir 中的 【\"  - '+.\"】 为 【\"  - DOMAIN-SUFFIX,\"】 以及 【\"- '\"】 为 【\"  - DOMAIN-SUFFIX,\"】 成功！"

    sed -i -e "s/  - 'SRC-IP-CIDR/  - SRC-IP-CIDR/g" \
        -e "s/  - 'IP-CIDR/  - IP-CIDR/g" \
        "$file_full_dir" >/dev/null
    logger "删除 $file_full_dir 中 SRC-IP-CIDR 和 IP-CIDR 前的单引号成功！"

    sed -i -E '/^[[:space:]]*(#|$)/! {
                    /^  - (IP-CIDR|SRC-IP-CIDR)/ {
                        /,no-resolve$/! { s/$/,no-resolve/ }
                    }
                }' "$file_full_dir" >/dev/null
    logger "为 $file_full_dir 中 SRC-IP-CIDR 和 IP-CIDR 行的末尾添加 no-resolve 成功！"
}

ipcidr_rules_replace() {
    local file_full_dir=$1
    sed -i "s/'$//g" "$file_full_dir" >/dev/null
    logger "删除 $file_full_dir 中行尾的单引号 成功！"

    sed -i "s/  - '/  - IP-CIDR,/g" "$file_full_dir" >/dev/null
    logger "替换 $file_full_dir 中的 \"- '\" 为 \"  - IP-CIDR,\" 成功！"

    sed -i -e "s/  - 'SRC-IP-CIDR/  - SRC-IP-CIDR/g" -e "s/  - 'IP-CIDR/  - IP-CIDR/g" "$file_full_dir" >/dev/null
    logger "删除 $file_full_dir 中 SRC-IP-CIDR 和 IP-CIDR 前的单引号成功！"
    
    # 最后2行排除已经被替换过的行
    sed -i -e "s/'IP-CIDR/  - IP-CIDR/g" \
        -e "s/'SRC-IP-CIDR/  - SRC-IP-CIDR/g" \
        -e "/^  - IP-CIDR/! s/IP-CIDR/  - IP-CIDR/g" \
        -e "/^  - SRC-IP-CIDR/! s/SRC-IP-CIDR/  - SRC-IP-CIDR/g" \
        "$file_full_dir" >/dev/null
    logger "把 $file_full_dir 中 "'IP-CIDR..." 和 "IP-CIDR..." 以及 "'SRC-IP-CIDR" 和 "SRC-IP-CIDR"替换成 " - SRC-IP-CIDR"(yaml缩进及前缀横杠)！"

    sed -i -E '/^  - IP-CIDR/! { /\<([0-9]{1,3}\.){3}[0-9]{1,3}\>/ s/(.*)/  - IP-CIDR,\1/ }' "$file_full_dir" >/dev/null
    logger "把 $file_full_dir 中所有纯IP替换成以 " - IP-CIDR" 开头(yaml缩进及前缀横杠)！"

    sed -i -E '/^[[:space:]]*(#|$)/! {
                /^  - (IP-CIDR|SRC-IP-CIDR)/ {
                    /,no-resolve$/! { 
                        s/$/,no-resolve/ 
                    }
                }
            }' "$file_full_dir" >/dev/null
    logger "为 $file_full_dir 中 SRC-IP-CIDR 和 IP-CIDR 行的末尾添加 no-resolve 成功！"

    # 追加 payload: 至顶部
    payload_count=$(awk '!/^[[:space:]]*(#|$)/ && /payload:/ && NF > 0' "$file_full_dir" | wc -l)
    if [ $payload_count -eq 0 ]; then
        payload="payload: "
        sed -i "1i$payload" "$file_full_dir" >/dev/null
        logger "为 $file_full_dir 补全 payload: 成功！"
    fi
}

is_ruleset_validate_yaml() {
    local file_name=$1
    local file_full_dir=$2
    local ruby_file="$SCRIPTS_DIR/validate_yaml.rb"

    ruby -e "
        require '$ruby_file';
        exit_code = 0;

        result1 = is_first_line_payload('$file_full_dir', '$LOG_FILE');
        exit_code = 1 if result1 == 1;
        result2 = is_validate_yaml('$file_full_dir', '$LOG_FILE');
        exit_code = 1 if result2 == 1;
        
        exit exit_code;
    "
    if [ ! $? -eq 0 ]; then
        logger "$file_name 文件格式校验失败，可能是下载时出了异常，跳过本规则集！"
        return 1
    fi
    return 0
}