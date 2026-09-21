#!/usr/bin/env bash
# Para os containers do hub (WebODM + ClusterODM). Os dados (projetos, fotos,
# banco de dados) ficam guardados e voltam do jeito que estavam no próximo start.sh.
set -e
cd "$(dirname "$0")"

if docker compose version >/dev/null 2>&1; then
  docker compose down
else
  docker-compose down
fi
