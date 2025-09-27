#!/bin/bash

mv loom loom
cd loom

mv loom-system loom-system
mv loom-tg-bot loom-tg-bot
mv loom-release-tg-bot loom-release-tg-bot
mv loom-account loom-account
mv loom-authorization loom-authorization
mv loom-employee loom-employee
mv loom-organization loom-organization
mv loom-content loom-content

cd loom-system && git remote set-url origin git@github.com:LoomAI-IT/loom-system.git && cd ..
cd loom-tg-bot && git remote set-url origin git@github.com:LoomAI-IT/loom-system.git && cd ..
cd loom-release-tg-bot && git remote set-url origin git@github.com:LoomAI-IT/loom-release-tg-bot.git && cd ..
cd loom-account && git remote set-url origin git@github.com:LoomAI-IT/loom-account.git && cd ..
cd loom-authorization && git remote set-url origin git@github.com:LoomAI-IT/loom-authorization.git && cd ..
cd loom-employee && git remote set-url origin git@github.com:LoomAI-IT/loom-employee.git && cd ..
cd loom-organization && git remote set-url origin git@github.com:LoomAI-IT/loom-organization.git && cd ..
cd loom-content && git remote set-url origin git@github.com:LoomAI-IT/loom-content.git && cd ..

cd loom/loom-system && export $(cat env/.env.app env/.env.db env/.env.monitoring | xargs) && docker compose -f ./docker-compose/app.yaml up --build