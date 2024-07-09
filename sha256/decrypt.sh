#!/bin/bash

# do_decrypt() {
#     bark_sha256_password="bark_sha256_password"
#     local ppwd
#     declare -A hashmap
#     if [ -f "$bark_sha256_password" ]; then
#         while IFS='=' read -r k v; do
#             # 忽略空行和注释行（以#开头）
#             if [[ -n "$k" && ! "$k" =~ ^\s*# ]]; then
#                 if [ "$k" = "password" ]; then
#                     ppwd="$v"
#                     break
#                 fi
#             fi
#         done <"$bark_sha256_password"
#     fi

#     echo "ppwd===================$ppwd" >>error.log
#     echo -n "" > "decrypted_result"

#     local encrypted_result="encrypted_result"
#     local iterations=1000
#     local decrypted_result
#     if [ -f "$encrypted_result" ]; then
#         while IFS='=' read -r k v; do
#             echo "解密读取到的key=====$k, 读取到的value=====$v" >>error.log
#             if [[ -n "$k" && ! "$k" =~ ^\s*# ]]; then
#                 decrypted_result=$(openssl enc -aes-256-cbc -pbkdf2 -iter $iterations -d -a -pass pass:"$ppwd" <<<"$v")
#                 echo "$k=$decrypted_result" >>decrypted_result
#                 echo "key====$k, value===$decrypted_result \n" >>error.log
#             fi
#         done <"$encrypted_result"
#     fi

#     # 删除不需要文件
#     rm "encrypted_result" 2>/dev/null
# }

do_decrypt() {
    iterations=1000
    passwd="$(head -n 1 /etc/openclash/rule_provider/sha256/bark_sha256_password)"
    value=$1
    decrypted_result=$(openssl enc -aes-256-cbc -pbkdf2 -iter $iterations -d -a -pass pass:"$passwd" <<<"$value")
}

do_decrypt $1