#!/bin/bash

CONFIG_DIR="/configs/proxy_users"

echo "[*] Старт всех пользователей..."

for cfg in "$CONFIG_DIR"/*.cfg; do
  echo "[+] Запуск $(basename "$cfg")"
  /usr/local/3proxy/bin/3proxy "$cfg" &
done

echo "[*] Все пользователи запущены ✅"
