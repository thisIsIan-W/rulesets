# /bin/bash
. $PWD/base.sh

# Documentation: https://bark.day.app/#/encryption
push_notification() {
    local push_title="$1"
    local push_body="$2"

    encrypted_deviceKey="U2FsdGVkX1/4ZpX7VeztU6fOabZXhrNFkHi4yNuUjxiHHru+R657NEPADRDa7lPf"
    encrypted_key="U2FsdGVkX1+ttdUfGCkXwORU5q1vCjWO1+QwvXCus8eo0RbBCKKWccuNtC3S0TbZ"
    encrypted_iv="U2FsdGVkX1/lduGY4+8UlBZ0qU1Augum43sd3NIMq52YzkIWFtqDyUhZrpDWvE7h"

    deviceKey=$(bash /etc/openclash/rule_provider/sha256/decrypt.sh $encrypted_deviceKey)
    key=$(bash /etc/openclash/rule_provider/sha256/decrypt.sh $encrypted_key)
    iv=$(bash /etc/openclash/rule_provider/sha256/decrypt.sh $encrypted_iv)
    iv_tmp="$iv"

    logger "deviceKey=================$deviceKey"
    logger "key=================$key"
    logger "iv=================$iv"

    json=$(printf '{"title": "%s", "body":"%s", "sound":"bell"}' "$push_title" "$push_body")

    key=$(printf $key | xxd -ps -c 200)
    iv=$(printf $iv | xxd -ps -c 200)
    ciphertext=$(echo -n $json | openssl enc -aes-128-cbc -K $key -iv $iv | base64 -w 0)

    curl --data-urlencode "ciphertext=$ciphertext" --data-urlencode "iv=$iv_tmp" https://api.day.app/$deviceKey
}