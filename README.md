# WebODM em cluster (para computadores fracos)

Este repositório monta um **WebODM** (para você criar projetos e ver os resultados
no navegador) que distribui o processamento pesado entre **vários computadores**
Linux na mesma rede, usando o **ClusterODM** como "gerente de fila" e o
**NodeODM** como o programa que efetivamente processa as fotos em cada máquina.

Tudo roda em Docker — não precisa instalar Python, ODM, nem nada disso à mão.

## Como funciona (resumo)

```
                    ┌───────────────────────────────┐
                    │   COMPUTADOR "HUB"             │
  seu navegador --> │   WebODM  (interface web)      │
                    │       │                        │
                    │       v                        │
                    │   ClusterODM (fila/gerente)     │
                    │    │        │        │          │
                    │    v        │        │          │
                    │ NodeODM     │        │          │
                    │ (local)     │        │          │
                    └─────┼───────┼────────┼──────────┘
                          │       │        │
                     (na própria  v        v
                       máquina) NodeODM  NodeODM
                              worker 1  worker 2 ...
                              (outros computadores na rede)
```

- Você acessa o **WebODM** pelo navegador, só em UM computador (o "hub").
- O WebODM manda cada tarefa de processamento para o **ClusterODM**.
- O ClusterODM escolhe, entre os computadores disponíveis (o hub e os
  "workers"), qual está livre para processar aquela tarefa, e manda pra lá.
- Cada computador "worker" só precisa rodar o **NodeODM** — não precisa nem
  abrir navegador nele.

### O que esse "cluster" realmente distribui

Isso distribui **tarefas inteiras** entre as máquinas: se você criar 3 projetos
(tasks) ao mesmo tempo, cada um pode ir para um computador diferente, e todos
processam em paralelo. Isso já ajuda bastante quando você tem várias máquinas
fracas em vez de uma forte.

O que isso **não** faz por padrão: pegar **um único** conjunto de fotos muito
grande e dividir automaticamente o processamento dele entre várias máquinas
(isso existe no ClusterODM, chama "split-merge", mas exige armazenamento
compatível com S3 configurado à parte — não está incluso aqui para manter a
coisa simples). Para testes com poucas dezenas de fotos por vez, o que está
aqui já resolve.

## O que cada computador precisa

- Linux (testado pensando em Linux Mint, mas qualquer distro Ubuntu/Debian
  serve).
- **Docker** instalado (instruções abaixo). Só isso — nada de Python, GDAL,
  etc.
- Estar na **mesma rede local** (mesmo Wi-Fi/roteador) que os outros
  computadores do cluster.
- Espaço em disco livre (alguns GB, para as imagens Docker + fotos + resultados).

Como as máquinas são fracas, é só um experimento mesmo: use poucas fotos por
tarefa (por exemplo, 10–30 fotos) para os testes. Ver a seção
[Dicas para máquinas fracas](#dicas-para-máquinas-fracas) mais abaixo.

## Passo 1 — Instalar o Docker em TODOS os computadores

Em cada computador (hub e workers), abra o Terminal e rode:

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

Depois **saia da sessão e entre de novo** (ou reinicie o computador) para o
grupo `docker` valer. Para conferir se funcionou:

```bash
docker run hello-world
```

Se aparecer uma mensagem dizendo "Hello from Docker!", está tudo certo.

## Passo 2 — Escolher o computador "hub"

Escolha **um** dos computadores para ser o "hub" — é nele que vai rodar o
WebODM e que você vai acessar pelo navegador. Pode ser o mais forte dos
fracos, mas qualquer um serve.

Em **todos** os computadores (hub e workers), clone este repositório:

```bash
git clone <url-deste-repositorio> webodm-cluster
cd webodm-cluster
```

## Passo 3 — Subir o hub

**No computador escolhido como hub:**

```bash
cd webodm-cluster/hub
chmod +x start.sh register-node.sh stop.sh
./start.sh
```

Isso baixa as imagens Docker (pode demorar alguns minutos na primeira vez,
dependendo da internet) e sobe:
- WebODM (interface web)
- ClusterODM (gerente de fila)
- Um NodeODM local (o próprio hub também processa)

No final, o script mostra o IP desta máquina e os próximos passos. Anote esse
IP — os outros computadores vão usá-lo.

Abra no navegador: `http://localhost:8000` (no próprio hub) ou
`http://IP-DO-HUB:8000` (de qualquer outro computador/celular na rede).

Na primeira vez, o WebODM vai pedir para você **criar a conta de
administrador** — crie um usuário e senha.

Depois, no menu do WebODM vá em **Processing Nodes** (Nós de processamento) e
adicione um nó novo com:
- **Hostname:** `clusterodm`
- **Port:** `3000`

Pronto — a partir de agora, toda tarefa que você criar no WebODM passa pelo
ClusterODM.

## Passo 4 — Adicionar computadores "worker"

**Em cada outro computador** que vai ajudar a processar:

```bash
cd webodm-cluster/worker
chmod +x start.sh stop.sh
./start.sh
```

O script mostra o IP dessa máquina no final.

**De volta no hub**, registre cada worker (uma vez para cada um):

```bash
cd webodm-cluster/hub
./register-node.sh <ip-do-worker>
```

Exemplo: `./register-node.sh 192.168.1.42`

Confira se deu certo abrindo, no navegador, o painel do ClusterODM:

`http://IP-DO-HUB:10000`

Você deve ver a lista de nós (o `nodeodm-local` e cada worker registrado),
todos com status **online**.

> Se você reiniciar o hub (`./stop.sh` + `./start.sh`), o nó local
> (`nodeodm-local`) é registrado de novo automaticamente, mas os workers
> remotos **precisam ser registrados de novo** rodando `./register-node.sh
> <ip>` para cada um.

## Passo 5 — Usar

No WebODM (`http://IP-DO-HUB:8000`), crie um projeto, suba as fotos e inicie o
processamento normalmente. O WebODM manda a tarefa para o ClusterODM, que
escolhe automaticamente uma máquina livre (hub ou algum worker) para
processar. Você acompanha o progresso na tela do WebODM, como de costume.

## Parar tudo

No hub:
```bash
cd webodm-cluster/hub && ./stop.sh
```

Em cada worker:
```bash
cd webodm-cluster/worker && ./stop.sh
```

Os projetos, fotos e resultados ficam guardados (em volumes do Docker) mesmo
depois de parar — ao rodar `./start.sh` de novo, tudo volta como estava.

Se quiser **apagar tudo** (inclusive os projetos) e começar do zero:
```bash
cd webodm-cluster/hub
docker compose down -v
```

## Dicas para máquinas fracas

- Comece com **poucas fotos** (10–30) só para validar que o fluxo funciona
  ponta a ponta antes de tentar algo maior.
- Se a máquina tiver pouca RAM (4 GB ou menos), considere aumentar o **swap**
  para evitar que o processo morra por falta de memória:
  ```bash
  sudo fallocate -l 4G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  ```
  (para o swap valer depois de reiniciar, adicione `/swapfile swap swap
  defaults 0 0` ao `/etc/fstab`)
- Feche programas pesados (navegador com muitas abas, etc.) enquanto uma
  tarefa está processando na máquina.
- Se uma máquina worker estiver muito fraca até para o NodeODM sozinho, você
  pode simplesmente não registrá-la (ou tirá-la do cluster com
  `NODE REMOVE` — veja "Administração avançada" abaixo) e usá-la só como
  cliente (acessando o WebODM pelo navegador).

## Solução de problemas

- **Um worker aparece offline no painel (porta 10000 do hub):**
  - Confirme que o worker está rodando: `docker ps` na máquina worker deve
    mostrar o container `nodeodm`.
  - Confirme que as duas máquinas conseguem se "ver" na rede: no hub, rode
    `ping <ip-do-worker>`.
  - Verifique se algum firewall está bloqueando a porta 3000. No Linux Mint,
    se o `ufw`/Gufw estiver ativo:
    ```bash
    sudo ufw allow 3000/tcp
    ```
    (rode isso na máquina worker)
- **Não consigo acessar `http://IP-DO-HUB:8000` de outro computador:**
  - Mesma ideia: libere a porta 8000 no firewall do hub (`sudo ufw allow
    8000/tcp`), e confirme que estão na mesma rede.
- **`./start.sh` diz que Docker Compose não foi encontrado:**
  - Reabra o terminal depois de instalar o Docker, ou rode `docker compose
    version` para conferir se foi instalado certo.
- **Quero ver os nós registrados ou remover um manualmente:** veja
  "Administração avançada" abaixo.

## Administração avançada (opcional)

O ClusterODM tem um console de administração via `telnet` na porta 8080 do
hub. De dentro da máquina hub:

```bash
telnet localhost 8080
```

Comandos úteis dentro do telnet:
- `NODE LIST` — lista os nós e o status de cada um
- `NODE ADD <ip> <porta>` — adiciona um nó (é o que `register-node.sh` faz)
- `NODE REMOVE <numero>` — remove um nó (o número aparece em `NODE LIST`)
- `HELP` — lista todos os comandos disponíveis

## Estrutura deste repositório

```
webodm-cluster/
├── hub/
│   ├── docker-compose.yml   # WebODM + ClusterODM + NodeODM local
│   ├── .env.example         # configurações (copiado para .env automaticamente)
│   ├── start.sh             # sobe tudo no hub
│   ├── register-node.sh     # registra um worker no ClusterODM
│   └── stop.sh              # para os containers do hub
└── worker/
    ├── docker-compose.yml   # só o NodeODM
    ├── start.sh             # sobe o NodeODM neste computador
    └── stop.sh              # para o NodeODM
```

## Créditos

Este repositório só organiza e automatiza o uso de projetos open-source
existentes: [WebODM](https://github.com/OpenDroneMap/WebODM),
[NodeODM](https://github.com/OpenDroneMap/NodeODM) e
[ClusterODM](https://github.com/OpenDroneMap/ClusterODM), todos da
[OpenDroneMap](https://www.opendronemap.org/).
