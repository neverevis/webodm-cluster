#!/usr/bin/env bash
# Registra uma máquina "worker" (rodando NodeODM) no ClusterODM.
# Rode isso NO HUB depois de iniciar o worker em outra máquina.
#
# Uso: ./register-node.sh <ip-da-maquina-worker> [porta]
# Exemplo: ./register-node.sh 192.168.1.42
set -e

HOST="$1"
PORT="${2:-3000}"

if [ -z "$HOST" ]; then
  echo "Uso: ./register-node.sh <ip-da-maquina-worker> [porta]"
  echo "Exemplo: ./register-node.sh 192.168.1.42"
  exit 1
fi

echo "Registrando ${HOST}:${PORT} no ClusterODM..."
exec 3<>/dev/tcp/127.0.0.1/8080
echo "NODE ADD ${HOST} ${PORT}" >&3
sleep 1
timeout 2 cat <&3 2>/dev/null || true
exec 3<&- 3>&-

echo ""
echo "Pronto (ou o nó já estava registrado)."
echo "Confira em http://localhost:10000 se ele aparece como 'online'."
echo "Se aparecer offline, confirme que:"
echo "  - o worker está rodando (./start.sh na máquina worker)"
echo "  - as duas máquinas estão na mesma rede/Wi-Fi"
echo "  - nenhum firewall está bloqueando a porta ${PORT}"
