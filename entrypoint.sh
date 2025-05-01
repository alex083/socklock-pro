#!/bin/bash

set -e

echo "[*] Запуск SockLock Pro..."

# Генерация конфигов
bash /scripts/generate_config.sh

# Запуск всех пользователей
bash /scripts/start_all_users.sh

# Старт watchdog (в фоне)
bash /scripts/watchdog.sh
