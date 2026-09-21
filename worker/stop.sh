#!/usr/bin/env bash
# Para o NodeODM nesta máquina worker.
set -e
cd "$(dirname "$0")"

if docker compose version >/dev/null 2>&1; then
  docker compose down
else
  docker-compose down
fi
