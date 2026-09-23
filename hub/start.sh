#!/usr/bin/env bash
# Sobe o WebODM + ClusterODM nesta máquina (o "hub" do cluster).
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

if [ ! -f .env ]; then
  cp .env.example .env
  if command -v openssl >/dev/null 2>&1; then
    SECRET=$(openssl rand -hex 24)
  else
    SECRET=$(head -c 48 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 48)
  fi
  # troca a linha WO_SECRET_KEY= pelo valor gerado
  awk -v s="$SECRET" '{ if ($0 ~ /^WO_SECRET_KEY=/) print "WO_SECRET_KEY="s; else print $0 }' .env > .env.tmp && mv .env.tmp .env
  echo "Arquivo .env criado com uma chave secreta gerada automaticamente."
fi

# O IP desta máquina pode mudar (DHCP), então atualizamos a cada execução.
# Ele é usado pelo ClusterODM para avisar os workers remotos como alcançá-lo
# durante uma tarefa dividida entre várias máquinas (opção "split").
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
if [ -z "$IP" ]; then
  echo "Aviso: não consegui detectar o IP desta máquina automaticamente."
  echo "O recurso de dividir uma tarefa entre workers (split) pode não funcionar"
  echo "até você definir HUB_IP manualmente no arquivo .env."
else
  awk -v ip="$IP" '{ if ($0 ~ /^HUB_IP=/) print "HUB_IP="ip; else print $0 }' .env > .env.tmp && mv .env.tmp .env
fi

echo "Subindo os containers (WebODM + ClusterODM + NodeODM local)..."
$DC up -d

echo ""
echo "Aguardando o ClusterODM ficar pronto..."
READY=0
for i in $(seq 1 30); do
  if (exec 3<>/dev/tcp/127.0.0.1/8080) 2>/dev/null; then
    exec 3<&- 3>&-
    READY=1
    break
  fi
  sleep 1
done

if [ "$READY" = "1" ]; then
  echo "Registrando o NodeODM local no ClusterODM..."
  # dá um tempinho extra pro nodeodm-local também estar de pé
  sleep 3
  exec 3<>/dev/tcp/127.0.0.1/8080
  echo "NODE ADD nodeodm-local 3000" >&3
  sleep 1 || true
  timeout 2 cat <&3 2>/dev/null || true
  exec 3<&- 3>&- 2>/dev/null || true
else
  echo "Aviso: não consegui falar com o ClusterODM na porta 8080 ainda."
  echo "Rode manualmente depois: ./register-node.sh nodeodm-local 3000"
fi

PORT=$(grep -E '^WO_PORT=' .env | cut -d= -f2)
PORT=${PORT:-8000}
CLUSTERODM_PORT=$(grep -E '^CLUSTERODM_PORT=' .env | cut -d= -f2)
CLUSTERODM_PORT=${CLUSTERODM_PORT:-3001}

echo ""
echo "=========================================================="
echo "Tudo certo! Agora:"
echo "1) Abra no navegador: http://localhost:${PORT}"
echo "   (de outro computador na mesma rede: http://${IP:-<ip-deste-computador>}:${PORT})"
echo "2) Crie a conta de administrador quando pedir."
echo "3) Em Configurações > Nós de processamento, adicione um nó com:"
echo "   Endereço: clusterodm   |   Porta: 3000"
echo "4) Painel do ClusterODM (mostra os nós conectados):"
echo "   http://localhost:10000  (ou http://${IP:-<ip-deste-computador>}:10000)"
echo "5) Para várias máquinas processarem A MESMA tarefa em paralelo, use a"
echo "   opção 'split' ao criar a tarefa no WebODM - veja o README.md."
echo "   Para isso funcionar com workers em outras máquinas, libere a porta"
echo "   ${CLUSTERODM_PORT} no firewall deste computador (o hub)."
echo "=========================================================="
