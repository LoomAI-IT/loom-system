# PostgreSQL Physical Backup System

Система физических бэкапов для PostgreSQL инстансов проекта Loom с использованием `pg_basebackup`.

## Возможности

- Физический бэкап PostgreSQL через `pg_basebackup`
- Автоматическая ротация бэкапов (хранятся 3 последних)
- Автоматические уведомления в Telegram
- Логирование всех операций
- Автоматизация через cron (ежедневно в 03:00)
- Удобные команды Make для управления

## Структура

```
loom-system/
├── backups/postgresql/      # Бэкапы
│   ├── account/
│   ├── authorization/
│   ├── employee/
│   ├── organization/
│   ├── content/
│   └── tg-bot/
├── logs/
│   └── backup.log           # Логи операций
└── script/backup/
    ├── pg_backup.sh         # Бэкап одного инстанса
    ├── pg_backup_all.sh     # Бэкап всех инстансов
    ├── pg_restore.sh        # Восстановление
    ├── pg_list_backups.sh   # Список бэкапов
    └── install_cron.sh      # Установка cron
```

## Быстрый старт

### 1. Установка автоматических бэкапов

```bash
# Через Make
make install-backup-cron

# Или напрямую
./script/backup/install_cron.sh
```

Это установит cron задачу для ежедневного бэкапа в 03:00.

### 2. Ручной бэкап

```bash
# Бэкап всех инстансов
make backup

# Бэкап конкретного инстанса
make backup-account
make backup-authorization
make backup-employee
make backup-organization
make backup-content
make backup-tg-bot
```

### 3. Просмотр бэкапов

```bash
# Все бэкапы
make list-backups

# Только для конкретного инстанса
./script/backup/pg_list_backups.sh account
```

### 4. Восстановление из бэкапа

```bash
make restore INSTANCE=account BACKUP=backups/postgresql/account/account_backup_20250112_030000.tar.gz
```

**ВНИМАНИЕ:** Восстановление удалит все текущие данные! Перед удалением создается резервная копия.

## Подробное описание

### Бэкап одного инстанса

```bash
# Через Make
make backup-account

# Или напрямую
./script/backup/pg_backup.sh account
```

**Что происходит:**
1. Проверяется статус контейнера PostgreSQL
2. Запускается `pg_basebackup` внутри контейнера
3. Создается сжатый архив (gzip)
4. Бэкап сохраняется в `backups/postgresql/<instance>/`
5. Удаляются старые бэкапы (оставляются 3 последних)
6. Отправляется уведомление в Telegram
7. Записываются логи

**Формат имени файла:**
```
<instance>_backup_<timestamp>.tar.gz
<instance>_backup_<timestamp>_wal.tar.gz  # WAL архив если есть
```

Пример: `account_backup_20250112_030000.tar.gz`

### Бэкап всех инстансов

```bash
make backup
```

Последовательно запускает бэкап для всех 6 инстансов:
- account
- authorization
- employee
- organization
- content
- tg-bot

После завершения отправляет итоговый отчет в Telegram.

### Восстановление

```bash
make restore INSTANCE=<instance> BACKUP=<path_to_backup>
```

**Пример:**
```bash
make restore INSTANCE=account BACKUP=backups/postgresql/account/account_backup_20250112_030000.tar.gz
```

**Что происходит:**
1. Запрашивается подтверждение (нужно ввести `yes`)
2. Останавливается контейнер PostgreSQL
3. Создается резервная копия текущих данных
4. Очищается директория `volumes/postgresql/<instance>/`
5. Распаковывается бэкап
6. Устанавливаются правильные права доступа (999:999)
7. Запускается контейнер
8. Проверяется, что PostgreSQL запустился успешно
9. Отправляется уведомление в Telegram

**ВАЖНО:**
- Процесс необратим (но создается резервная копия)
- Требуется подтверждение
- Downtime на время восстановления (обычно 1-5 минут)

### Список бэкапов

```bash
# Все инстансы
make list-backups

# Конкретный инстанс
./script/backup/pg_list_backups.sh account
```

Показывает:
- Имя файла
- Размер (с учетом WAL)
- Дату создания
- Полный путь
- Итоговую статистику

### Автоматизация через cron

```bash
make install-backup-cron
```

Устанавливает задачу:
```cron
0 3 * * * /path/to/loom-system/script/backup/pg_backup_all.sh >> /path/to/logs/backup.log 2>&1
```

**Управление cron:**

Просмотр:
```bash
crontab -l
```

Редактирование:
```bash
crontab -e
```

Удаление:
```bash
crontab -l | grep -v "loom-postgresql-backup" | crontab -
```

## Telegram уведомления

Используется существующий скрипт `script/tg_bot_alert.py`.

**Требуемые переменные окружения:**
- `LOOM_ALERT_TG_BOT_TOKEN` - токен бота
- `LOOM_ALERT_TG_CHAT_ID` - ID чата для уведомлений

**Типы уведомлений:**
- Успешный бэкап одного инстанса
- Неудачный бэкап одного инстанса
- Итоговый отчет по всем бэкапам
- Успешное восстановление
- Неудачное восстановление

## Логирование

Все операции логируются в `logs/backup.log`.

**Просмотр логов:**
```bash
# Последние записи
tail -f logs/backup.log

# Поиск по дате
grep "2025-01-12" logs/backup.log

# Только ошибки
grep "ERROR" logs/backup.log
```

## Технические детали

### Переменные окружения

Скрипты автоматически загружают переменные из всех файлов в `prod_env/`:
- `prod_env/.env.app` - переменные приложения
- `prod_env/.env.db` - переменные баз данных (контейнеры, пользователи, пароли)
- `prod_env/.env.monitoring` - переменные мониторинга и алертов

Переменные экспортируются автоматически при запуске скриптов, не требуется ручная настройка.

**Важные переменные для бэкапа:**
- `LOOM_*_POSTGRES_CONTAINER_NAME` - имена контейнеров PostgreSQL
- `LOOM_*_POSTGRES_USER` - пользователи PostgreSQL
- `LOOM_*_POSTGRES_PASSWORD` - пароли PostgreSQL
- `LOOM_*_POSTGRES_VOLUME_DIR` - пути к volume директориям
- `LOOM_ALERT_TG_BOT_TOKEN` - токен Telegram бота для уведомлений
- `LOOM_ALERT_TG_CHAT_ID` - ID чата для уведомлений

### pg_basebackup

Используемые флаги:
- `-D /backup` - директория назначения
- `-F tar` - формат tar
- `-z` - сжатие gzip
- `-P` - показ прогресса
- `-U <user>` - пользователь PostgreSQL
- `-w` - без запроса пароля (используется PGPASSWORD)

### Хранение бэкапов

По умолчанию хранятся **3 последних бэкапа** для каждого инстанса.

Для изменения отредактируйте `RETENTION_COUNT` в `pg_backup.sh`:
```bash
RETENTION_COUNT=3  # Изменить на нужное значение
```

### Права доступа

PostgreSQL требует owner `999:999` для директорий данных.
Скрипт восстановления автоматически устанавливает правильные права.

Если возникают проблемы с правами:
```bash
sudo chown -R 999:999 volumes/postgresql/<instance>/
chmod -R 700 volumes/postgresql/<instance>/pgdata
```

### Размер бэкапов

Примерные размеры (зависит от данных):
- Пустая БД: ~25-30 MB (сжато)
- Малая БД (< 1 GB): 50-200 MB
- Средняя БД (1-10 GB): 200 MB - 2 GB

Учитывайте место на диске: 6 инстансов × 3 бэкапа × средний размер.

## Устранение неполадок

### Бэкап не запускается

**Проверьте:**
1. Контейнер запущен: `docker ps | grep postgres`
2. Скрипты исполняемые: `ls -la script/backup/`
3. Переменные окружения: `source prod_env/.env.db && echo $LOOM_ACCOUNT_POSTGRES_CONTAINER_NAME`

### Недостаточно места

```bash
# Проверка места
df -h

# Ручная очистка старых бэкапов
rm backups/postgresql/*/old_backup_*.tar.gz

# Список больших файлов
du -h backups/postgresql/*/*.tar.gz | sort -h
```

### Восстановление не удается

**Проверьте:**
1. Файл бэкапа существует и не поврежден
2. Достаточно места в `volumes/postgresql/<instance>/`
3. Правильные права доступа
4. Логи контейнера: `docker logs loom-<instance>-postgres`

### Telegram уведомления не приходят

**Проверьте:**
1. Переменные окружения установлены
2. Скрипт исполняемый: `ls -la script/tg_bot_alert.py`
3. Python 3 установлен: `python3 --version`
4. Библиотека requests: `pip3 list | grep requests`

## Примеры использования

### Ежедневная проверка

```bash
# Проверить список бэкапов
make list-backups

# Проверить логи за сегодня
grep "$(date +%Y-%m-%d)" logs/backup.log
```

### Бэкап перед обновлением

```bash
# Сделать бэкап всех БД
make backup

# Подождать завершения и проверить
make list-backups
```

### Тестирование восстановления

```bash
# 1. Сделать бэкап
make backup-account

# 2. Найти последний бэкап
make list-backups

# 3. Восстановить
make restore INSTANCE=account BACKUP=backups/postgresql/account/account_backup_YYYYMMDD_HHMMSS.tar.gz

# 4. Проверить работу
docker exec loom-account-postgres psql -U account-user -d account -c "SELECT version();"
```

### Миграция на новый сервер

```bash
# На старом сервере
make backup

# Скопировать бэкапы
scp -r backups/postgresql/ user@new-server:/path/to/loom-system/backups/

# На новом сервере
cd /path/to/loom-system
make restore INSTANCE=account BACKUP=backups/postgresql/account/account_backup_YYYYMMDD_HHMMSS.tar.gz
# Повторить для всех инстансов
```

## Безопасность

1. **Бэкапы содержат чувствительные данные** - храните их в безопасном месте
2. **Ограничьте доступ** к директории `backups/`: `chmod 700 backups/`
3. **Пароли в памяти** - скрипты используют переменные окружения, пароли не логируются
4. **Удаленное хранение** - рассмотрите копирование бэкапов на удаленный сервер
5. **Шифрование** - для критичных данных используйте шифрование бэкапов

## FAQ

**Q: Можно ли делать бэкап без остановки контейнера?**
A: Да! `pg_basebackup` работает online, контейнер не останавливается.

**Q: Как часто нужно делать бэкапы?**
A: Зависит от критичности данных. По умолчанию - ежедневно в 03:00.

**Q: Можно ли восстановить на другой версии PostgreSQL?**
A: Физические бэкапы работают только на той же мажорной версии (у вас 17.x).

**Q: Что делать если бэкап слишком большой?**
A: Рассмотрите инкрементальные бэкапы или pgBackRest. Или используйте pg_dump для логических бэкапов.

**Q: Как проверить целостность бэкапа?**
A: Лучший способ - тестовое восстановление на dev окружении.

**Q: Нужно ли бэкапить release-tg-bot?**
A: Сейчас он исключен из автоматических бэкапов. Добавьте в `INSTANCES` в `pg_backup_all.sh` если нужно.

## Дополнительная информация

- [PostgreSQL pg_basebackup документация](https://www.postgresql.org/docs/17/app-pgbasebackup.html)
- [PostgreSQL Backup and Restore](https://www.postgresql.org/docs/17/backup.html)

## Поддержка

При проблемах проверьте:
1. Логи: `logs/backup.log`
2. Логи контейнеров: `docker logs <container>`
3. Статус контейнеров: `docker ps`
4. Место на диске: `df -h`
