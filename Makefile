.PHONY: deploy build-all stop-all update-all rebuild-all
.PHONY: rebuild-app stop-app
.PHONY: rebuild-monitoring stop-monitoring
.PHONY: rebuild-db stop-db
.PHONY: set-env set-env-to-config-template
.PHONY: backup backup-account backup-authorization backup-employee backup-organization backup-content backup-tg-bot
.PHONY: list-backups restore install-backup-cron

set-env:
	@export $(cat env/.env.app env/.env.db env/.env.monitoring | xargs)

set-env-to-config-template:
	@envsubst < ${LOOM_LOKI_CONFIG_FILE}.template > ${LOOM_LOKI_CONFIG_FILE}
	@envsubst < ${LOOM_MONITORING_REDIS_CONFIG_FILE}.template > ${LOOM_MONITORING_REDIS_CONFIG_FILE}
	@envsubst < ${LOOM_TEMPO_CONFIG_FILE}.template > ${LOOM_TEMPO_CONFIG_FILE}
	@envsubst < ${LOOM_OTEL_COLLECTOR_CONFIG_FILE}.template > ${LOOM_OTEL_COLLECTOR_CONFIG_FILE}

deploy:
	@apt update && apt upgrade -y
	@apt install python3-pip git make
	@pip install requests --break-system-packages
	@cd ..
	@git clone git@github.com:LoomAI-IT/loom-admin-panel.git
	@git clone git@github.com:LoomAI-IT/loom-landing.git
	@git clone git@github.com:LoomAI-IT/loom-tg-bot.git
	@git clone git@github.com:LoomAI-IT/loom-release-tg-bot.git
	@git clone git@github.com:LoomAI-IT/loom-tg-custdev.git
	@git clone git@github.com:LoomAI-IT/loom-account.git
	@git clone git@github.com:LoomAI-IT/loom-authorization.git
	@git clone git@github.com:LoomAI-IT/loom-employee.git
	@git clone git@github.com:LoomAI-IT/loom-organization.git
	@git clone git@github.com:LoomAI-IT/loom-content.git
	@git clone git@github.com:LoomAI-IT/loom-internal-dashboard.git
	@cd loom-system
	@./infrastructure/nginx/install.sh
	@./infrastructure/docker/install.sh
	@mkdir -p backups/postgresql/{account,authorization,employee,organization,content,tg-bot,tg-custdev} logs script/backup
	@mkdir -p volumes/{grafana,loki,tempo,redis,postgresql,victoria-metrics,tg-bot-api}
	@mkdir -p volumes/redis/monitoring
	@mkdir -p volumes/weed
	@mkdir -p volumes/postgresql/{tg-bot,tg-custdev,release-tg-bot,account,authorization,employee,organization,content,grafana}
	@chmod -R 777 volumes
	@docker build -f script/migration/Dockerfile -t migration-base:latest .

build-all: set-env-to-config-template
	@docker compose -f ./docker-compose/db.yaml up --build
	sleep 20
	@docker compose -f ./docker-compose/monitoring.yaml up --build
	sleep 20
	@docker compose -f ./docker-compose/app.yaml up --build


stop-all:
	@docker compose -f ./docker-compose/app.yaml down
	@docker compose -f ./docker-compose/monitoring.yaml down
	@docker compose -f ./docker-compose/db.yaml down

update-all:
	@git pull
	@cd ../loom-tg-bot/ && git fetch origin && git checkout main && git reset --hard origin/main && cd ../loom-system/
	@cd ../loom-landing/ && git fetch origin && git checkout main && git reset --hard origin/main && cd ../loom-system/
	@cd ../loom-release-tg-bot/ && git fetch origin && git checkout main && git reset --hard origin/main && cd ../loom-system/
	@cd ../loom-tg-custdev/ && git fetch origin && git checkout main && git reset --hard origin/main && cd ../loom-system/
	@cd ../loom-account/ && git fetch origin && git checkout main && git reset --hard origin/main && cd ../loom-system/
	@cd ../loom-authorization/ && git fetch origin && git checkout main && git reset --hard origin/main && cd ../loom-system/
	@cd ../loom-employee/ && git fetch origin && git checkout main && git reset --hard origin/main && cd ../loom-system/
	@cd ../loom-organization/ && git fetch origin && git checkout main && git reset --hard origin/main && cd ../loom-system/
	@cd ../loom-content/ && git fetch origin && git checkout main && git reset --hard origin/main && cd ../loom-system/
	@cd ../loom-internal-dashboard/ && git fetch origin && git checkout main && git reset --hard origin/main && cd ../loom-system/

rebuild-all: update-all build-all

rebuild-app: update-all set-env-to-config-template
	@docker compose -f ./docker-compose/apps.yaml up -d --build

stop-app:
	@docker compose -f ./docker-compose/apps.yaml down

stop-monitoring:
	@docker compose -f ./docker-compose/monitoring.yaml down

stop-db:
	@docker compose -f ./docker-compose/db.yaml down

rebuild-monitoring: update-all set-env-to-config-template
	@docker compose -f ./docker-compose/monitoring.yaml down
	@docker compose -f ./docker-compose/monitoring.yaml up -d --build

rebuild-db: update-all set-env-to-config-template
	@docker compose -f ./docker-compose/db.yaml down
	@docker compose -f ./docker-compose/db.yaml up -d --build

# PostgreSQL Backup Commands

backup:
	@echo "Starting backup for all PostgreSQL instances..."
	@./script/backup/pg_backup_all.sh

backup-account:
	@echo "Starting backup for account instance..."
	@./script/backup/pg_backup.sh account

backup-authorization:
	@echo "Starting backup for authorization instance..."
	@./script/backup/pg_backup.sh authorization

backup-employee:
	@echo "Starting backup for employee instance..."
	@./script/backup/pg_backup.sh employee

backup-organization:
	@echo "Starting backup for organization instance..."
	@./script/backup/pg_backup.sh organization

backup-content:
	@echo "Starting backup for content instance..."
	@./script/backup/pg_backup.sh content

backup-tg-bot:
	@echo "Starting backup for tg-bot instance..."
	@./script/backup/pg_backup.sh tg-bot

list-backups:
	@./script/backup/pg_list_backups.sh

restore:
	@if [ -z "$(INSTANCE)" ] || [ -z "$(BACKUP)" ]; then \
		echo "Error: INSTANCE and BACKUP parameters are required"; \
		echo "Usage: make restore INSTANCE=<instance> BACKUP=<path_to_backup>"; \
		echo "Example: make restore INSTANCE=account BACKUP=backups/postgresql/account/account_backup_20250112_030000.tar.gz"; \
		exit 1; \
	fi
	@echo "Starting restore for instance: $(INSTANCE)"
	@echo "Backup file: $(BACKUP)"
	@./script/backup/pg_restore.sh $(INSTANCE) $(BACKUP)

install-backup-cron:
	@echo "Installing cron job for automatic backups..."
	@./script/backup/install_cron.sh