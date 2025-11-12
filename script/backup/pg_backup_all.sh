#!/bin/bash
#
# Физический бэкап всех PostgreSQL инстансов
#
# Использование: ./pg_backup_all.sh
#
# Запускает pg_backup.sh последовательно для всех инстансов:
# - account
# - authorization
# - employee
# - organization
# - content
# - tg-bot
#

set -euo pipefail

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_FILE="${PROJECT_ROOT}/logs/backup.log"
ENV_DIR="${PROJECT_ROOT}/env"
TG_ALERT_SCRIPT="${PROJECT_ROOT}/script/tg_bot_alert.py"
BACKUP_SCRIPT="${SCRIPT_DIR}/pg_backup.sh"

# Загрузка переменных окружения из всех env файлов
for env_file in "${ENV_DIR}"/.env.{app,db,monitoring}; do
    if [[ -f "${env_file}" ]]; then
        set -a
        source "${env_file}"
        set +a
    fi
done

# Список инстансов для бэкапа (основные 6, без release-tg-bot)
INSTANCES=("account" "authorization" "employee" "organization" "content" "tg-bot")

# Функция логирования
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Функция отправки Telegram уведомления
send_telegram() {
    local message="$1"
    if [[ -x "${TG_ALERT_SCRIPT}" ]]; then
        # Явно передаем переменные окружения в Python процесс
        LOOM_ALERT_TG_BOT_TOKEN="${LOOM_ALERT_TG_BOT_TOKEN}" \
        LOOM_ALERT_TG_CHAT_ID="${LOOM_ALERT_TG_CHAT_ID}" \
        python3 "${TG_ALERT_SCRIPT}" "${message}" || log "WARN" "Failed to send Telegram notification"
    else
        log "WARN" "Telegram alert script not found or not executable: ${TG_ALERT_SCRIPT}"
    fi
}

# Проверка наличия скрипта бэкапа
if [[ ! -x "${BACKUP_SCRIPT}" ]]; then
    log "ERROR" "Backup script not found or not executable: ${BACKUP_SCRIPT}"
    exit 1
fi

# Начало процесса бэкапа
START_TIME=$(date +%s)
log "INFO" "=========================================="
log "INFO" "Starting backup for all PostgreSQL instances"
log "INFO" "Instances to backup: ${INSTANCES[*]}"
log "INFO" "=========================================="

# Счетчики для статистики
SUCCESSFUL_COUNT=0
FAILED_COUNT=0
declare -a FAILED_INSTANCES

# Бэкап каждого инстанса
for instance in "${INSTANCES[@]}"; do
    log "INFO" "---"
    log "INFO" "Processing instance: ${instance}"

    if "${BACKUP_SCRIPT}" "${instance}"; then
        log "INFO" "Backup successful for instance: ${instance}"
        ((SUCCESSFUL_COUNT++))
    else
        log "ERROR" "Backup failed for instance: ${instance}"
        FAILED_INSTANCES+=("${instance}")
        ((FAILED_COUNT++))
    fi

    # Небольшая пауза между бэкапами для снижения нагрузки
    if [[ ${instance} != "${INSTANCES[-1]}" ]]; then
        sleep 5
    fi
done || true

# Подсчет времени выполнения
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$((DURATION / 60))
DURATION_SEC=$((DURATION % 60))

# Итоговая статистика
log "INFO" "=========================================="
log "INFO" "Backup process completed"
log "INFO" "Total instances: ${#INSTANCES[@]}"
log "INFO" "Successful: ${SUCCESSFUL_COUNT}"
log "INFO" "Failed: ${FAILED_COUNT}"
log "INFO" "Duration: ${DURATION_MIN}m ${DURATION_SEC}s"
log "INFO" "=========================================="

# Формирование сообщения для Telegram
if [[ ${FAILED_COUNT} -eq 0 ]]; then
    # Все бэкапы успешны
    TELEGRAM_MESSAGE="✅ <b>ВСЕ БЭКАПЫ УСПЕШНО ЗАВЕРШЕНЫ</b>

📊 Статистика:
  • Всего инстансов: <b>${#INSTANCES[@]}</b>
  • Успешно: <b>${SUCCESSFUL_COUNT}</b> ✅
  • Ошибок: <b>${FAILED_COUNT}</b>

⏱️ Время выполнения: <b>${DURATION_MIN}м ${DURATION_SEC}с</b>
🕐 Завершено: $(date '+%d.%m.%Y %H:%M:%S')

🎉 Все базы данных защищены!"

    send_telegram "${TELEGRAM_MESSAGE}"
    log "INFO" "All backups completed successfully"
    exit 0
else
    # Есть неудачные бэкапы
    FAILED_LIST=$(printf '%s\n' "${FAILED_INSTANCES[@]}" | sed 's/^/  - /')

    TELEGRAM_MESSAGE="⚠️ <b>БЭКАП ЗАВЕРШЁН С ОШИБКАМИ</b>

📊 Статистика:
  • Всего инстансов: <b>${#INSTANCES[@]}</b>
  • Успешно: <b>${SUCCESSFUL_COUNT}</b> ✅
  • Ошибок: <b>${FAILED_COUNT}</b> ❌

❌ Не удалось сделать бэкап:
${FAILED_LIST}

⏱️ Время выполнения: <b>${DURATION_MIN}м ${DURATION_SEC}с</b>
🕐 Завершено: $(date '+%d.%m.%Y %H:%M:%S')

⚡ Требуется внимание!"

    send_telegram "${TELEGRAM_MESSAGE}"
    log "ERROR" "Some backups failed. Check logs for details."
    exit 1
fi
