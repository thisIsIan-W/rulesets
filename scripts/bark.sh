# /bin/bash

# Documentation: https://bark.day.app/#/encryption
push_notification() {
    local push_title="$1"
    local push_body="$2"
    deviceKey='HqCrrAgbvdGSeFsHPJzmph'
    json=$(printf '{"title": "%s", "body":"%s", "sound":"bell"}' "$push_title" "$push_body")
    key='1472587412583645'
    iv='hfAQHmKvW:#7jFJl'

    key=$(printf $key | xxd -ps -c 200)
    iv=$(printf $iv | xxd -ps -c 200)

    ciphertext=$(echo -n $json | openssl enc -aes-128-cbc -K $key -iv $iv | base64 -w 0)

    curl --data-urlencode "ciphertext=$ciphertext" --data-urlencode "iv=hfAQHmKvW:#7jFJl" https://api.day.app/$deviceKey
}