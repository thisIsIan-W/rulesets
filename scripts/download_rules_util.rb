require 'logger'
require 'singleton'
require 'open3'
require 'json'

PUSH_SECRET_PATH = "/etc/openclash/rule_provider/sha256/bark_sha256_password"
PUSH_SECRET_DECRYPT_SHELL_PATH = "/etc/openclash/rule_provider/sha256/decrypt.sh"
ENCRYPTED_DEVICE_KEY = "U2FsdGVkX19JoDCN9YkkGBB3bQGe4weTdLMQr/e4j++mgIW2m34FdQB4HX8QlxnQ"
ENCRYPTED_KEY = "U2FsdGVkX18Tch9LZrXlwn3Xl7OnXgCjP+HvQFlLJD+zwMtnivcRTJewqUDXY37R"
ENCRYPTED_IV = "U2FsdGVkX19VYMZqYNojhuOfHLCFJh4wNdqoLPC/NGchh9+rWns5hurxEoHyltz8"

class Push

  def push(extra_push_message)

    stdout, stderr, status = Open3.capture3("bash #{PUSH_SECRET_DECRYPT_SHELL_PATH} #{ENCRYPTED_DEVICE_KEY}")
    if status.success?
      device_key = stdout.strip
    end

    stdout, stderr, status = Open3.capture3("bash #{PUSH_SECRET_DECRYPT_SHELL_PATH} #{ENCRYPTED_KEY}")
    if status.success?
      key = stdout.strip
    end

    stdout, stderr, status = Open3.capture3("bash #{PUSH_SECRET_DECRYPT_SHELL_PATH} #{ENCRYPTED_IV}")
    if status.success?
      iv = stdout.strip
    end

    ciphertext_command = %Q{echo -n "$(printf '{"title": "%s", "body":"%s", "sound":"bell"}' "更新 openclash 第三方规则集结果" "#{extra_push_message}")" | \
        openssl enc -aes-128-cbc -K "$(printf "#{key}" | xxd -ps -c 200)" -iv "$(printf "#{iv}" | xxd -ps -c 200)" | base64 -w 0}

    stdout, stderr, status = Open3.capture3(ciphertext_command)
    if status.success?
      ciphertext = stdout.strip
    end


    request_data_map = {
      "ciphertext" => ciphertext,
      "iv" => iv
    }
    curl_request("https://api.day.app/#{device_key}", request_data_map)
  end

  def curl_request(url, request_data_map, use_ssl: true, method: 'POST')
    uri = URI.parse(url)
    request = Net::HTTP.const_get(method.capitalize).new(uri)
    request['Content-Type'] = 'application/json'
    request.body = request_data_map.to_json
    begin
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        response = http.request(request)
        if response.code.to_i == 200
          return 0
        else
          return response.code.to_i
        end
      end
    rescue Exception => e
      return 1
    end
  end
end

class ExecShellCommand

  def self.exec_shell_command(command, source_dir: nil)
    raise "命令不能为空！" if command.nil? || command.empty? || command == ''

    command = substitute_placeholders(command, source_dir)
    stdout, stderr, status = Open3.capture3(command)
    if stderr.empty?
      return stdout, status
    else
      return stderr, status
    end
  end

  def self.substitute_placeholders(command, source_dir)
    command = command.gsub('{source_dir}', source_dir) if source_dir
    command
  end

end