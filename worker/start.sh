#!/usr/bin/env bash
# Sobe o NodeODM nesta máquina, para ela virar um "worker" do cluster.
# Uso: ./start.sh
set -e
cd "$(dirname "$0")"

if command -v docker compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DC="docker-compose"
else
  echo "Docker Compose não foi encontrado. Veja o README.md para instalar o Docker antes de continuar."
  exit 1
fi

echo "Subindo o NodeODM..."
$DC up -d

IP=$(hostname -I 2>/dev/null | awk '{print $1}')

echo ""
echo "=========================================================="
echo "NodeODM rodando nesta máquina."
echo "IP desta máquina: ${IP:-<não detectado, rode: ip addr>}"
echo ""
echo "Agora vá até a máquina do HUB e rode, dentro da pasta hub/:"
echo "   ./register-node.sh ${IP:-<ip-desta-maquina>}"
echo "=========================================================="
