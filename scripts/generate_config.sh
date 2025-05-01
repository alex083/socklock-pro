#!/bin/bash

set -e

# === Настройки ===
API_URL=${API_URL:-https://api.runonflux.io/apps/location/proxypoolusa}
REMOTE_USER=${REMOTE_USER:-proxyuser}
REMOTE_PASS=${REMOTE_PASS:-proxypass}
REMOTE_PORT=${REMOTE_PORT:-3405}
CLIENT_PASS=${CLIENT_PASS:-clientpass}
PROXY_MODE=${PROXY_MODE:-socks5}
MAX_USERS=${MAX_USERS:-55}
START_USER_ID=${START_USER_ID:-5999}
SERVER_IP=$(curl -s ifconfig.me)

DB_FILE="/configs/socklock.db"
CONFIG_DIR="/configs/proxy_users"
PROXY_LIST="/configs/proxies.txt"

mkdir -p "$CONFIG_DIR"

init_db() {
  if [[ ! -f "$DB_FILE" ]]; then
    echo "[*] Инициализация базы данных..."
    sqlite3 "$DB_FILE" "CREATE TABLE proxies (user TEXT PRIMARY KEY, ip TEXT UNIQUE);"
  fi
}

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

generate_config() {
  echo "[*] Генерация конфигурации..."
  init_db

  for row in $(sqlite3 "$DB_FILE" "SELECT user || ':' || ip FROM proxies;"); do
    user="${row%%:*}"
    ip="${row#*:}"
    if ! check_proxy "$ip"; then
      echo "[-] $ip ($user) — нерабочий"
      sqlite3 "$DB_FILE" "UPDATE proxies SET ip = NULL WHERE user = '$user';"
    else
      echo "[✓] $ip ($user) — рабочий"
    fi
  done

  max_id=$(sqlite3 "$DB_FILE" "SELECT MAX(CAST(SUBSTR(user, 5) AS INTEGER)) FROM proxies;")
  max_id=${max_id:-$START_USER_ID}

  IP_LIST=$(curl -s "$API_URL" | jq -r '.data[].ip' | cut -d':' -f1)

  for ip in $IP_LIST; do
    exists=$(sqlite3 "$DB_FILE" "SELECT 1 FROM proxies WHERE ip = '$ip';")
    [[ "$exists" == "1" ]] && continue

    current_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM proxies WHERE ip IS NOT NULL;")
    if (( current_count >= MAX_USERS )); then
      echo "[!] Достигнуто максимальное количество активных прокси"
      break
    fi

    if check_proxy "$ip"; then
      free_user=$(sqlite3 "$DB_FILE" "SELECT user FROM proxies WHERE ip IS NULL LIMIT 1;")
      if [[ -n "$free_user" ]]; then
        sqlite3 "$DB_FILE" "UPDATE proxies SET ip = '$ip' WHERE user = '$free_user';"
        echo "[+] Назначен IP $ip для $free_user (повторно)"
      else
        ((max_id++))
        user="user$max_id"
        sqlite3 "$DB_FILE" "INSERT INTO proxies (user, ip) VALUES ('$user', '$ip');"
        echo "[+] Назначен IP $ip для $user (новый)"
      fi
    fi
  done

  echo "[*] Перегенерация конфигов на каждого пользователя..."
  > "$PROXY_LIST"
  
  # Удаляем старые конфиги
  rm -f "$CONFIG_DIR"/*.cfg

  while IFS=$'|' read -r user ip; do
    port=${user:4}
    config_path="$CONFIG_DIR/$user.cfg"

    {
      echo "nserver 8.8.8.8"
      echo "nscache 65536"
      echo "maxconn 100000"
      echo "auth strong"
      echo "users $user:CL:$CLIENT_PASS"
      echo "allow $user"
      echo "parent 1000 socks5 $ip $REMOTE_PORT $REMOTE_USER $REMOTE_PASS"
      if [[ "$PROXY_MODE" == "http" ]]; then
        echo "proxy -p$port -a -i0.0.0.0 -n"
      else
        echo "socks -p$port -a -i0.0.0.0 -n"
      fi
    } > "$config_path"

    echo "$PROXY_MODE://$user:$CLIENT_PASS@$SERVER_IP:$port" >> "$PROXY_LIST"

  done < <(sqlite3 -separator '|' "$DB_FILE" "SELECT user, ip FROM proxies WHERE ip IS NOT NULL;")

  echo "[*] Конфигурация обновлена ✅"
}

generate_config
