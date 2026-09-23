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

### O que esse "cluster" distribui

Tem dois jeitos de distribuir trabalho entre as máquinas, e os dois já vêm
prontos neste repositório:

1. **Tarefas inteiras em paralelo:** se você criar 2 ou 3 projetos ao mesmo
   tempo, cada um pode ir para um computador diferente, processando em
   paralelo. É o que acontece automaticamente, sem precisar configurar nada.
2. **Uma única tarefa dividida entre várias máquinas ("split"):** o ClusterODM
   também sabe pegar **um conjunto de fotos só** e dividir o processamento
   dele entre todos os workers disponíveis ao mesmo tempo, juntando o
   resultado no final. Isso é o que você quer quando tem várias máquinas
   fracas e quer que elas processem **a mesma tarefa** juntas, mais rápido.
   Não é automático por padrão — você escolhe isso na hora de criar a tarefa
   (ligando a opção "split"). Veja o [Passo 5](#passo-5--processar-uma-tarefa-em-várias-máquinas-ao-mesmo-tempo-split).

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

## Passo 5 — Usar (tarefa simples, processa em um nó só)

No WebODM (`http://IP-DO-HUB:8000`), crie um projeto, suba as fotos e inicie o
processamento normalmente. O WebODM manda a tarefa para o ClusterODM, que
escolhe automaticamente uma máquina livre (hub ou algum worker) para
processar. Você acompanha o progresso na tela do WebODM, como de costume.

Isso processa a tarefa inteira em **uma única máquina**. Se você quer que
**todos os workers ajudem na mesma tarefa ao mesmo tempo**, veja o próximo
passo.

## Passo 6 — Processar uma tarefa em várias máquinas ao mesmo tempo (split)

Esse é o recurso que faz várias máquinas fracas dividirem **o mesmo**
conjunto de fotos entre si, cada uma processando um pedaço em paralelo, e o
ClusterODM junta tudo no final. Já está tudo configurado nos scripts deste
repositório (o hub avisa o próprio IP pro ClusterODM automaticamente) — você
só precisa ligar essa opção na hora de criar a tarefa:

1. No WebODM, crie o projeto e suba as fotos normalmente.
2. Antes de clicar em "Start Processing", abra as **Opções de processamento**
   (o ícone de engrenagem/opções ao lado do botão de iniciar).
3. No campo de busca das opções, digite `split` e você vai ver duas opções:
   - **split**: quantas fotos, no máximo, cada "pedaço" (submodel) deve ter.
     Isso precisa ser **menor que o total de fotos** da tarefa para realmente
     dividir. Exemplo: se você subiu 20 fotos, coloque `split = 8` (ou 10)
     para forçar 2–3 pedaços, um pra cada worker.
   - **split-overlap**: sobreposição entre os pedaços, em metros (pode
     deixar no padrão para um teste rápido).
4. Inicie o processamento. Agora, no painel do ClusterODM
   (`http://IP-DO-HUB:10000`), você deve ver a fila (`Queue`) subir em mais
   de um nó ao mesmo tempo — é o sinal de que os workers estão processando a
   mesma tarefa juntos.

**Dica:** para não ter que digitar isso toda vez, salve essas opções como um
**preset** (o WebODM tem um botão de salvar/gerenciar presets de opções na
mesma tela) — daí é só selecionar o preset nas próximas tarefas.

> **Aviso para quem está testando com poucas fotos:** dividir datasets
> pequenos (poucas dezenas de fotos) em pedaços tende a deixar o resultado
> final com qualidade pior (cada pedaço tem pouca sobreposição entre si).
> Isso é normal e esperado no seu experimento — o objetivo aqui é ver as
> máquinas processando em paralelo, não necessariamente ter um modelo 3D
> perfeito. Em datasets grandes de verdade (centenas/milhares de fotos), usar
> `split` com valores maiores (ex: 200+) é uma prática real e recomendada.
>
> Também é preciso ter mais de um nó **online e livre** para o split
> realmente rodar em paralelo — com 2 workers, 2 pedaços processam ao mesmo
> tempo; o resto espera na fila.

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
- **Erro `port is already allocated` ao subir o hub:**
  - Alguma porta que o `docker-compose.yml` quer usar já está ocupada por
    outro programa/container nessa máquina. Descubra qual com:
    ```bash
    docker ps -a --format "table {{.Names}}\t{{.Ports}}"
    ```
    Se for a porta **3001** (a porta pública do ClusterODM) que está em
    conflito, edite `hub/.env` e mude `CLUSTERODM_PORT` para outro número
    (ex: `3002`), depois rode `./start.sh` de novo.
- **`register-node.sh` diz "Conexão recusada" na porta 8080:**
  - Provavelmente o container `clusterodm` não terminou de subir (ou caiu por
    causa de um conflito de porta, veja o item acima). Rode
    `docker compose ps` na pasta `hub/` e confira se `clusterodm` está `Up`.
- **O `split` não está dividindo a tarefa entre os workers (só um nó
  processa, ou os outros ficam "presos"/a tarefa trava):**
  - Confira se `hub/.env` tem um `HUB_IP=` preenchido com o IP correto desta
    máquina (o `start.sh` preenche sozinho a cada execução). Se o IP mudou
    recentemente (por exemplo o roteador trocou o IP da máquina), rode
    `./start.sh` de novo para atualizar, depois `docker compose up -d
    --force-recreate clusterodm`.
  - Libere a porta do ClusterODM (padrão **3001**) no firewall do hub, para
    os workers remotos conseguirem "telefonar de volta" durante o split:
    ```bash
    sudo ufw allow 3001/tcp
    ```
    (rode isso na máquina hub; se você mudou `CLUSTERODM_PORT`, libere a
    porta que você escolheu)
  - Confira se o valor de `split` é **menor** que o número de fotos da
    tarefa — se for igual ou maior, não há divisão.
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
