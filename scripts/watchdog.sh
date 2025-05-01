#!/bin/bash

set -e

DB_FILE="/configs/socklock.db"
CONFIG_DIR="/configs/proxy_users"
API_URL=${API_URL:-https://api.runonflux.io/apps/location/proxypoolusa}
REMOTE_USER=${REMOTE_USER:-proxyuser}
REMOTE_PASS=${REMOTE_PASS:-proxypass}
REMOTE_PORT=${REMOTE_PORT:-3405}
CLIENT_PASS=${CLIENT_PASS:-clientpass}
MAX_PARALLEL_CHECKS=${MAX_PARALLEL_CHECKS:-10}  # Ограничение количества одновременных проверок

check_proxy() {
  local ip=$1
  local result
  result=$(timeout 6 curl --silent --socks5-hostname "$REMOTE_USER:$REMOTE_PASS@$ip:$REMOTE_PORT" http://ip-api.com/json -m 6)
  local status=$?
  local extracted_ip=$(echo "$result" | jq -r '.query')
  if [[ $status -eq 0 && "$extracted_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    return 0
  fi
  return 1
}

replace_and_restart_user() {
  local user=$1
  local port=${user:4}

  echo "[~] Обновляем IP для $user..."

  IP_LIST=$(curl -s "$API_URL" | jq -r '.data[].ip' | cut -d':' -f1)

  for new_ip in $IP_LIST; do
    exists=$(sqlite3 "$DB_FILE" "SELECT 1 FROM proxies WHERE ip = '$new_ip';")
    [[ "$exists" == "1" ]] && continue

    if check_proxy "$new_ip"; then
      sqlite3 "$DB_FILE" "UPDATE proxies SET ip = '$new_ip' WHERE user = '$user';"

      config_path="$CONFIG_DIR/$user.cfg"
      {
        echo "nserver 8.8.8.8"
        echo "nscache 65536"
        echo "maxconn 100000"
        echo "auth strong"
        echo "users $user:CL:$CLIENT_PASS"
        echo "allow $user"
        echo "parent 1000 socks5 $new_ip $REMOTE_PORT $REMOTE_USER $REMOTE_PASS"
        echo "socks -p$port -a -i0.0.0.0 -n"
      } > "$config_path"

      pkill -f "$config_path" || true
      sleep 1
      /usr/local/3proxy/bin/3proxy "$config_path" &
      echo "[*] Перезапущен процесс для $user"
      return 0
    fi
  done

  echo "[-] Не удалось найти новый рабочий IP для $user"
  return 1
}

# === Главный цикл ===

while true; do
  echo "[*] Watchdog параллельно проверяет пользователей (MAX_PARALLEL_CHECKS=$MAX_PARALLEL_CHECKS)..."

  while IFS=$'|' read -r user ip; do
    # Ограничение количества фоновых задач
    while [[ $(jobs -r | wc -l) -ge $MAX_PARALLEL_CHECKS ]]; do
      sleep 0.2
    done

    (
      if ! check_proxy "$ip"; then
        echo "[-] Найден нерабочий IP у $user ($ip)"
        sqlite3 "$DB_FILE" "UPDATE proxies SET ip = NULL WHERE user = '$user';"
        replace_and_restart_user "$user"
      else
        echo "[✓] $ip ($user) — рабочий"
      fi
    ) &
  done < <(sqlite3 -separator '|' "$DB_FILE" "SELECT user, ip FROM proxies WHERE ip IS NOT NULL;")

  wait  # Дождаться всех проверок

  echo "[*] Пауза 5 минут перед следующей проверкой..."
  sleep 300
done
