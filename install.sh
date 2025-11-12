auto instalador portainer traeifk:

#!/bin/bash

############################################################
#               AUTO-INSTALADOR PORTAINER+TRAEFIK
#               Estilo “passo a passo” colorido
############################################################

# -------------- Cores / Estilos --------------
RESET="\e[0m"
GREEN="\e[32m"
BLUE="\e[34m"
WHITE="\e[97m"
YELLOW="\e[33m"
OK="[ ${GREEN}OK${RESET} ]"
INFO="[ ${BLUE}INFO${RESET} ]"
ERROR="[ \e[31mERRO${RESET} ]"

# -------------- Funções de Log --------------
function log_ok()    { echo -e "${OK} - $1"; }
function log_info()  { echo -e "${INFO} - $1"; }
function log_error() { echo -e "${ERROR} - $1"; }

# -------------- Banner Inicial --------------
clear
echo -e "${GREEN}                                                                              ${RESET}"
echo -e "${GREEN}                           .-----------------------.                          ${RESET}"
echo -e "${GREEN}                           | INICIANDO INSTALAÇÃO  |                          ${RESET}"
echo -e "${GREEN}                           '-----------------------'                          ${RESET}"
echo -e "${WHITE}  _______                      __              __                             ${RESET}"
echo -e "${WHITE} |       \                    |  \            |  \                            ${RESET}"
echo -e "${WHITE} | ▓▓▓▓▓▓▓\ ______   ______  _| ▓▓_    ______  \▓▓_______   ______   ______   ${RESET}"
echo -e "${WHITE} | ▓▓__/ ▓▓/      \ /      \|   ▓▓ \  |      \|  \       \ /      \ /      \  ${RESET}"
echo -e "${WHITE} | ▓▓    ▓▓  ▓▓▓▓▓▓\  ▓▓▓▓▓▓\\▓▓▓▓▓▓   \▓▓▓▓▓▓\ ▓▓ ▓▓▓▓▓▓▓\  ▓▓▓▓▓▓\  ▓▓▓▓▓▓\ ${RESET}"
echo -e "${WHITE} | ▓▓▓▓▓▓▓| ▓▓  | ▓▓ ▓▓   \▓▓ | ▓▓ __ /      ▓▓ ▓▓ ▓▓  | ▓▓ ▓▓    ▓▓ ▓▓   \▓▓ ${RESET}"
echo -e "${WHITE} | ▓▓     | ▓▓__/ ▓▓ ▓▓       | ▓▓|  \  ▓▓▓▓▓▓▓ ▓▓ ▓▓  | ▓▓ ▓▓▓▓▓▓▓▓ ▓▓       ${RESET}"
echo -e "${WHITE} | ▓▓      \▓▓    ▓▓ ▓▓        \▓▓  ▓▓\▓▓    ▓▓ ▓▓ ▓▓  | ▓▓\▓▓     \ ▓▓       ${RESET}"
echo -e "${WHITE}  \▓▓       \▓▓▓▓▓▓ \▓▓         \▓▓▓▓  \▓▓▓▓▓▓▓\▓▓\▓▓   \▓▓ \▓▓▓▓▓▓▓\▓▓       ${RESET}"
echo -e "${WHITE}                ________                             ______  __ __            ${RESET}"
echo -e "${WHITE}      __        |        \                           /      \|  \  \          ${RESET}"
echo -e "${WHITE}     |  \        \▓▓▓▓▓▓▓▓ ______   ______   ______ |  ▓▓▓▓▓▓\\▓▓ ▓▓   __     ${RESET}"
echo -e "${WHITE}   _ | ▓▓__        | ▓▓   /      \ |      \ /      \| ▓▓_  \▓▓  \ ▓▓  /  \    ${RESET}"
echo -e "${WHITE}  |    ▓▓  \       | ▓▓  |  ▓▓▓▓▓▓\ \▓▓▓▓▓▓\  ▓▓▓▓▓▓\ ▓▓ \   | ▓▓ ▓▓_/  ▓▓    ${RESET}"
echo -e "${WHITE}   \▓▓▓▓▓▓▓▓       | ▓▓  | ▓▓   \▓▓/      ▓▓ ▓▓    ▓▓ ▓▓▓▓   | ▓▓ ▓▓   ▓▓     ${RESET}"
echo -e "${WHITE}     | ▓▓          | ▓▓  | ▓▓     |  ▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓ ▓▓     | ▓▓ ▓▓▓▓▓▓\     ${RESET}"
echo -e "${WHITE}      \▓▓          | ▓▓  | ▓▓      \▓▓    ▓▓\▓▓     \ ▓▓     | ▓▓ ▓▓  \▓▓\    ${RESET}"
echo -e "${WHITE}                   \▓▓   \▓▓       \▓▓▓▓▓▓▓ \▓▓▓▓▓▓▓\▓▓      \▓▓\▓▓   \▓▓     ${RESET}"
echo -e "${WHITE}    ______ ______ ______ ______ ______ ______ ______ ______ ______ ______     ${RESET}"
echo -e "${WHITE}   |      \      \      \      \      \      \      \      \      \      \    ${RESET}"
echo -e "${WHITE}    \▓▓▓▓▓▓\▓▓▓▓▓▓\▓▓▓▓▓▓\▓▓▓▓▓▓\▓▓▓▓▓▓\▓▓▓▓▓▓\▓▓▓▓▓▓\▓▓▓▓▓▓\▓▓▓▓▓▓\▓▓▓▓▓▓    ${RESET}"
echo -e "${GREEN}                                                                              ${RESET}"
echo -e "${YELLOW}                               Auto Instalador                               ${RESET}"
echo -e "${YELLOW}           Minha Automação MilionárIA: https://automilionaria.trade          ${RESET}"
echo
   
#!/bin/bash

############################################################
#               AUTO-INSTALADOR PORTAINER+TRAEFIK
#               Estilo “passo a passo” colorido
############################################################

# -------------- Cores / Estilos --------------
RESET="\e[0m"
GREEN="\e[32m"
BLUE="\e[34m"
YELLOW="\e[33m"
WHITE="\e[97m"
OK="[ ${GREEN}OK${RESET} ]"
INFO="[ ${BLUE}INFO${RESET} ]"
ERROR="[ \e[31mERRO${RESET} ]"

# -------------- Funções de Log --------------
function log_ok()    { echo -e "${OK} - $1"; }
function log_info()  { echo -e "${INFO} - $1"; }
function log_error() { echo -e "${ERROR} - $1"; }

# -------------- Banner Inicial --------------
clear
echo -e "${GREEN}                                                                              ${RESET}"
echo -e "${GREEN}                           .-----------------------.                          ${RESET}"
echo -e "${GREEN}                           | INICIANDO INSTALAÇÃO  |                          ${RESET}"
echo -e "${GREEN}                           '-----------------------'                          ${RESET}"
echo -e "${YELLOW}                               Auto Instalador                               ${RESET}"
echo -e "${YELLOW}           Minha Automação MilionárIA: https://automilionaria.trade          ${RESET}"
echo
sleep 1

# Definimos o total de etapas para ir numerando
TOTAL_STEPS=14
STEP=1

# -------------- Helpers para etapas --------------
function print_step() {
  local msg="$1"
  echo -e "${STEP}/${TOTAL_STEPS} - ${OK} - ${msg}"
  STEP=$((STEP+1))
}

#############################################
# 1/14 - Atualizar Sistema
#############################################
print_step "Fazendo Upgrade do sistema (apt-get update && upgrade)"
sudo apt-get update && sudo apt-get upgrade -y
if [ $? -ne 0 ]; then
  log_error "Falha ao atualizar o sistema."
  exit 1
fi
log_ok "Sistema atualizado com sucesso."
sleep 1

#############################################
# 2/14 - Verificando/Instalando sudo
#############################################
print_step "Verificando/Instalando sudo"
if ! dpkg -l | grep -q sudo; then
  sudo apt-get install -y sudo
  if [ $? -ne 0 ]; then
    log_error "Falha ao instalar sudo."
    exit 1
  fi
fi
log_ok "sudo OK."
sleep 1

#############################################
# 3/14 - Verificando/Instalando apt-utils
#############################################
print_step "Verificando/Instalando apt-utils"
if ! dpkg -l | grep -q apt-utils; then
  sudo apt-get install -y apt-utils
  if [ $? -ne 0 ]; then
    log_error "Falha ao instalar apt-utils."
    exit 1
  fi
fi
log_ok "apt-utils OK."
sleep 1

#############################################
# 4/14 - Verificando/Instalando python3
#############################################
print_step "Verificando/Instalando python3"
if ! command -v python3 &>/dev/null; then
  sudo apt-get install -y python3
  if [ $? -ne 0 ]; then
    log_error "Falha ao instalar python3."
    exit 1
  fi
fi
log_ok "python3 OK."
sleep 1

#############################################
# 5/14 - Verificando/Instalando git
#############################################
print_step "Verificando/Instalando git"
if ! command -v git &>/dev/null; then
  sudo apt-get install -y git
  if [ $? -ne 0 ]; then
    log_error "Falha ao instalar git."
    exit 1
  fi
fi
log_ok "git OK."
sleep 1

#############################################
# 6/14 - Verificando/Instalando Docker
#############################################
print_step "Verificando/Instalando Docker"
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com -o get-docker.sh

  # Tenta instalar Docker e verifica conflitos de travas
  sh get-docker.sh
  if ! command -v docker &>/dev/null; then
    echo
    echo -e "${ERROR} - Falha ao instalar Docker. Tentando liberar possíveis travas do apt..."
    echo

    # Modo de recuperação
    sudo killall apt apt-get dpkg 2>/dev/null
    sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock
    sudo dpkg --configure -a
    sleep 2
    echo -e "${INFO} - Tentando novamente instalar Docker..."

    # Tenta novamente
    sh get-docker.sh
    if ! command -v docker &>/dev/null; then
      log_error "Instalação do Docker falhou novamente após tentar recuperar o sistema."
      exit 1
    fi
  fi
fi
log_ok "Docker OK."
sleep 1

#############################################
# 7/14 - Inicializando Docker Swarm
#############################################
print_step "Inicializando Docker Swarm (se não estiver ativo)"
SWARM_ACTIVE=$(docker info 2>/dev/null | grep "Swarm" | awk '{print $2}')
if [ "$SWARM_ACTIVE" != "active" ]; then
  log_info "Swarm não ativo. Tentando iniciar..."
  DETECTED_IP=$(hostname -I | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
  if [ -z "$DETECTED_IP" ]; then
    echo "Não foi possível detectar IP automaticamente."
    docker swarm init || true
  else
    echo
    echo -e "========================================"
    echo -e "             Detectamos o \e[32mIP: $DETECTED_IP\e[0m"
    echo -e "========================================\n"

    read -p "Este, é o mesmo IP apontado para o seu domínio? (s/n): " CONF_IP
    if [[ "$CONF_IP" =~ ^[Ss]$ ]]; then
      docker swarm init --advertise-addr "$DETECTED_IP" || true
    else
      read -p "Informe o IP público IPv4 correto: " USER_IP
      docker swarm init --advertise-addr "$USER_IP" || true
    fi
  fi

  # Verifica se o Swarm ficou ativo
  SWARM_ACTIVE_AGAIN=$(docker info 2>/dev/null | grep "Swarm" | awk '{print $2}')
  if [ "$SWARM_ACTIVE_AGAIN" != "active" ]; then
    log_error "Falha ao iniciar o Swarm. Verifique IP e tente novamente."
    exit 1
  else
    log_ok "Swarm inicializado com sucesso."
  fi
else
  log_ok "Swarm já está ativo."
fi
sleep 1

#############################################
# 8/14 - Coletando dados do usuário
#############################################
print_step "Coletando dados (rede interna, servidor, e-mail, domínio Portainer)"

while true; do
  echo
  echo "--------------------------------------"
  read -p $'\e[33mNome da rede interna (overlay): \e[0m' NETWORK_NAME
  read -p $'\e[33mNome do servidor (descrição/hostname): \e[0m' SERVER_NAME
  read -p $'\e[33mE-mail para Let\'s Encrypt (Traefik): \e[0m' EMAIL_LETSENCRYPT
  read -p $'\e[33mDomínio para Portainer (ex.: portainer.meudominio.com): \e[0m' PORTAINER_DOMAIN
  read -p $'\e[33mCloudflare API Token (DNS Edit da zona; ENTER para pular e usar HTTP-01): \e[0m' CF_DNS_API_TOKEN
  # ...

  # --- Sanitização do domínio (remove http/https e barras finais) ---
  PORTAINER_DOMAIN=${PORTAINER_DOMAIN#http://}
  PORTAINER_DOMAIN=${PORTAINER_DOMAIN#https://}
  PORTAINER_DOMAIN=${PORTAINER_DOMAIN%/}

  # Mensagem centralizada, entre barras
  echo
  echo "========================================"
  echo -e "             Você informou:"
  echo -e "               - Rede interna: \e[32m$NETWORK_NAME\e[0m"
  echo -e "               - Nome do servidor: \e[32m$SERVER_NAME\e[0m"
  echo -e "               - E-mail: \e[32m$EMAIL_LETSENCRYPT\e[0m"
  echo -e "               - Domínio Portainer: \e[32mhttps://$PORTAINER_DOMAIN\e[0m"
  if [ -n "$CF_DNS_API_TOKEN" ]; then
    echo -e "               - Modo ACME: \e[32mDNS-01 (Cloudflare)\e[0m"
  else
    echo -e "               - Modo ACME: \e[33mHTTP-01 (porta 80 aberta, proxy desligado)\e[0m"
  fi
  echo "========================================"
  echo

  read -p "Está tudo correto? (s/n): " CONF_ALL
  if [[ "$CONF_ALL" =~ ^[Ss]$ ]]; then
    break
  fi
  echo "Ok, vamos refazer..."
done
sleep 1

#############################################
# 9/14 - Criando volumes
#############################################
print_step "Criando volumes (portainer_data, volume_swarm_shared, volume_swarm_certificates)"
docker volume create portainer_data
docker volume create volume_swarm_shared
docker volume create volume_swarm_certificates
sleep 1

#############################################
# 10/14 - Criando rede overlay
#############################################
print_step "Criando rede overlay '$NETWORK_NAME'"
docker network create --driver overlay --attachable "$NETWORK_NAME" || true
sleep 1

#############################################
# 11/14 - Gerando stack do Portainer
#############################################
print_step "Gerando arquivo /tmp/stack-portainer.yml"
cat > /tmp/stack-portainer.yml <<EOF
version: "3.7"

services:
  agent:
    image: portainer/agent:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
    networks:
      - ${NETWORK_NAME}
    deploy:
      mode: global
      placement:
        constraints:
          - node.platform.os == linux

  portainer:
    image: portainer/portainer-ce:latest
    command: -H tcp://tasks.agent:9001 --tlsskipverify
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - ${NETWORK_NAME}
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.portainer.rule=Host(\`${PORTAINER_DOMAIN}\`)"
        - "traefik.http.routers.portainer.entrypoints=websecure"
        - "traefik.http.routers.portainer.tls=true"
        - "traefik.http.routers.portainer.tls.certresolver=letsencryptresolver"
        - "traefik.http.services.portainer.loadbalancer.server.port=9000"
        - "traefik.http.routers.portainer.service=portainer"
        - "traefik.docker.network=${NETWORK_NAME}"
        - "traefik.http.routers.portainer.priority=1"

networks:
  ${NETWORK_NAME}:
    external: true
    name: ${NETWORK_NAME}

volumes:
  portainer_data:
    external: true
    name: portainer_data
EOF
log_ok "Stack Portainer criado em /tmp/stack-portainer.yml"
sleep 1

#############################################
# 12/14 - Gerando stack do Traefik
#############################################
print_step "Gerando arquivo /tmp/stack-traefik.yml"

# --- Garante acme.json no volume com permissão correta ---
CERT_PATH="/var/lib/docker/volumes/volume_swarm_certificates/_data"
sudo mkdir -p "$CERT_PATH"
sudo touch "$CERT_PATH/acme.json"
sudo chmod 600 "$CERT_PATH/acme.json"

# --- Bloco ACME dinâmico (HTTP-01 x DNS-01 Cloudflare) ---
if [ -n "$CF_DNS_API_TOKEN" ]; then
  ACME_BLOCK=$(cat <<'ACME'
      # Let's Encrypt (ACME DNS-01 via Cloudflare)
      - "--certificatesresolvers.letsencryptresolver.acme.dnschallenge=true"
      - "--certificatesresolvers.letsencryptresolver.acme.dnschallenge.provider=cloudflare"
ACME
)
  ENV_BLOCK=$(cat <<ENVVARS
    environment:
      - CF_DNS_API_TOKEN=${CF_DNS_API_TOKEN}
ENVVARS
)
else
  ACME_BLOCK=$(cat <<'ACME'
      # Let's Encrypt (ACME HTTP-01)
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web"
ACME
)
  ENV_BLOCK=""
fi

cat > /tmp/stack-traefik.yml <<EOF
version: "3.7"

services:
  traefik:
    image: traefik:v2.11.30
    command:
      # Descoberta via Docker/Swarm
      - "--api.dashboard=true"
      - "--providers.docker.swarmMode=true"
      - "--providers.docker.endpoint=unix:///var/run/docker.sock"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=${NETWORK_NAME}"

      # Entrypoints HTTP/HTTPS
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
      - "--entrypoints.websecure.address=:443"

      # Preservar IP real do cliente
      - "--entrypoints.web.forwardedHeaders.insecure=true"
      - "--entrypoints.websecure.forwardedHeaders.insecure=true"

      # Timeouts upstream
      - "--serversTransport.forwardingTimeouts.dialTimeout=30s"
      - "--serversTransport.forwardingTimeouts.responseHeaderTimeout=60s"
      - "--serversTransport.forwardingTimeouts.idleConnTimeout=90s"

${ACME_BLOCK}
      - "--certificatesresolvers.letsencryptresolver.acme.storage=/etc/traefik/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencryptresolver.acme.email=${EMAIL_LETSENCRYPT}"

      # Logs (stdout)
      - "--log.level=INFO"
      - "--accesslog=true"

${ENV_BLOCK}
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"

        # Redirecionar HTTP->HTTPS catch-all
        - "traefik.http.middlewares.redirect-https.redirectscheme.scheme=https"
        - "traefik.http.middlewares.redirect-https.redirectscheme.permanent=true"
        - "traefik.http.routers.http-catchall.rule=Host(\`{host:.+}\`)"
        - "traefik.http.routers.http-catchall.entrypoints=web"
        - "traefik.http.routers.http-catchall.middlewares=redirect-https@docker"
        - "traefik.http.routers.http-catchall.priority=1"

        ###################################################################
        # Middlewares globais definidos no Traefik (reutilizáveis)
        ###################################################################
        - "traefik.http.middlewares.compress.compress=true"

        # Buffering — permite uploads maiores (ex.: imagens, PDFs)
        - "traefik.http.middlewares.buffering.buffering.maxRequestBodyBytes=20000000"
        - "traefik.http.middlewares.buffering.buffering.maxResponseBodyBytes=20000000"
        - "traefik.http.middlewares.buffering.buffering.memRequestBodyBytes=2097152"
        - "traefik.http.middlewares.buffering.buffering.retryExpression=IsNetworkError() && Attempts() <= 2"

        # Rate limit "alto e seguro" na borda
        - "traefik.http.middlewares.ratelimit-public.ratelimit.period=1m"
        - "traefik.http.middlewares.ratelimit-public.ratelimit.average=120"
        - "traefik.http.middlewares.ratelimit-public.ratelimit.burst=240"

        # Security headers básicos (sem quebrar widget)
        - "traefik.http.middlewares.secure-headers.headers.referrerPolicy=no-referrer-when-downgrade"
        - "traefik.http.middlewares.secure-headers.headers.stsSeconds=31536000"
        - "traefik.http.middlewares.secure-headers.headers.stsIncludeSubdomains=true"
        - "traefik.http.middlewares.secure-headers.headers.stsPreload=true"
        - "traefik.http.middlewares.secure-headers.headers.browserXssFilter=true"
        - "traefik.http.middlewares.secure-headers.headers.contentTypeNosniff=true"

    volumes:
      - volume_swarm_certificates:/etc/traefik/letsencrypt
      - /var/run/docker.sock:/var/run/docker.sock:ro

    ports:
      - target: 80
        published: 80
        mode: host
      - target: 443
        published: 443
        mode: host

    networks:
      - ${NETWORK_NAME}

volumes:
  volume_swarm_shared:
    external: true
    name: volume_swarm_shared

  volume_swarm_certificates:
    external: true
    name: volume_swarm_certificates

networks:
  ${NETWORK_NAME}:
    external: true
    name: ${NETWORK_NAME}
EOF
log_ok "Stack Traefik criado em /tmp/stack-traefik.yml"
sleep 1

#############################################
# 13/14 - Fazendo deploy do Portainer
#############################################
print_step "Deploy do Portainer (docker stack deploy)"
docker stack deploy -c /tmp/stack-portainer.yml portainer
sleep 2

#############################################
# 14/14 - Fazendo deploy do Traefik
#############################################
print_step "Deploy do Traefik (docker stack deploy)"
docker stack deploy -c /tmp/stack-traefik.yml traefik
sleep 5

echo -e "\n${OK} - Deploy enviado. Verificando status..."

# --------- Verificação ROBUSTA (até 90s) ----------
MAX_WAIT=90
ELAPSED=0
until \
  [ "$(docker stack ps portainer --format '{{.CurrentState}}' 2>/dev/null | grep -c Running)" -gt 0 ] && \
  [ "$(docker stack ps traefik   --format '{{.CurrentState}}' 2>/dev/null | grep -c Running)"   -gt 0 ]; do
  sleep 3
  ELAPSED=$((ELAPSED+3))
  if [ $ELAPSED -ge $MAX_WAIT ]; then
    break
  fi
done

P_STATUS=$(docker stack ps portainer --format "{{.CurrentState}}" 2>/dev/null | grep -c "Running")
T_STATUS=$(docker stack ps traefik   --format "{{.CurrentState}}" 2>/dev/null | grep -c "Running")

if [[ "$P_STATUS" -gt 0 && "$T_STATUS" -gt 0 ]]; then
  echo
  echo "========================================"
  echo -e "       ${GREEN}Instalação concluída com sucesso!${RESET}"
  echo -e "       ${INFO} - Rede interna: \e[33m$NETWORK_NAME\e[0m"
  echo -e "       ${INFO} - Nome do Servidor: \e[33m$SERVER_NAME\e[0m"
  echo -e "       ${INFO} - E-mail Let's Encrypt: \e[33m$EMAIL_LETSENCRYPT\e[0m"
  echo -e "       ${INFO} - Domínio do Portainer: \e[33mhttps://${PORTAINER_DOMAIN}\e[0m"
  echo
  echo -e "       ${BLUE}Para verificar detalhes:${RESET}"
  echo -e "       docker stack ps portainer"
  echo -e "       docker stack ps traefik"
  echo
  echo -e "       ${INFO} - Minha Automação MilionárIA: \e[33mhttps://automilionaria.trade\e[0m"
  echo "========================================"
  echo

  # Mensagem de destaque sobre prazo de login
  echo -e "       \e[31mATENÇÃO:\e[0m Você tem \e[31mAPENAS 5 minutos\e[0m para fazer seu primeiro login no Portainer."
  echo -e "       Caso ultrapasse esse tempo, será necessário \e[31mrefazer toda a instalação.\e[0m"
  echo
else
  log_error "Um ou mais serviços não estão em Running."
  echo "------ Serviços ------"
  docker service ls
  echo "------ PS Portainer ------"
  docker service ps portainer_portainer --no-trunc
  echo "------ PS Traefik ------"
  docker service ps traefik_traefik --no-trunc
  echo "------ Logs Traefik (últimos 200) ------"
  docker service logs traefik_traefik -n 200
  echo "------ Logs Portainer (últimos 100) ------"
  docker service logs portainer_portainer -n 100
  echo "------ Portas 80/443 ocupadas? ------"
  ss -ltnp | egrep ':80 |:443 ' || true
  echo "-----------------------"
  echo "Verifique as mensagens acima, corrija e rode novamente."
  exit 1
fi
