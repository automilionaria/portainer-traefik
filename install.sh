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
OK="[ ${GREEN}OK${RESET} ]"
INFO="[ ${BLUE}INFO${RESET} ]"
ERROR="[ \e[31mERRO${RESET} ]"

# -------------- Funções de Log --------------
function log_ok()    { echo -e "${OK} - $1"; }
function log_info()  { echo -e "${INFO} - $1"; }
function log_error() { echo -e "${ERROR} - $1"; }

# -------------- Banner Inicial --------------
clear
echo -e "${BLUE}===============================================================================${RESET}"
echo -e "${GREEN}                           .-----------------------.                          ${RESET}"
echo -e "${GREEN}                           | INICIANDO INSTALAÇÃO  |                          ${RESET}"
echo -e "${GREEN}                           '-----------------------'                          ${RESET}"
echo -e "${BLUE}===============================================================================${RESET}\n"
echo -e "${WHITE}                                                                              ${RESET}"
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
echo -e "${WHITE}                   \▓▓   \▓▓       \▓▓▓▓▓▓▓ \▓▓▓▓▓▓▓\▓▓      \▓▓\▓▓   \▓▓     ${RESET}\n"

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
  sh get-docker.sh
  if ! command -v docker &>/dev/null; then
    log_error "Falha ao instalar Docker!"
    exit 1
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
    echo "Detectamos o IP: $DETECTED_IP"
    read -p "Este é o IP público? (s/n): " CONF_IP
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
  echo -e "\n--------------------------------------"
  read -p "Nome da rede interna (overlay): " NETWORK_NAME
  read -p "Nome do servidor (descrição/hostname): " SERVER_NAME
  read -p "E-mail para Let's Encrypt (Traefik): " EMAIL_LETSENCRYPT
  read -p "Domínio para Portainer (ex.: portainer.meudominio.com): " PORTAINER_DOMAIN

  echo -e "\nVocê informou:"
  echo " - Rede interna: $NETWORK_NAME"
  echo " - Nome do servidor: $SERVER_NAME"
  echo " - E-mail: $EMAIL_LETSENCRYPT"
  echo " - Domínio Portainer: https://$PORTAINER_DOMAIN"
  
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
        - traefik.enable=true
        - traefik.http.routers.portainer.rule=Host(\`${PORTAINER_DOMAIN}\`)
        - traefik.http.services.portainer.loadbalancer.server.port=9000
        - traefik.http.routers.portainer.tls.certresolver=letsencryptresolver
        - traefik.http.routers.portainer.service=portainer
        - traefik.docker.network=${NETWORK_NAME}
        - traefik.http.routers.portainer.entrypoints=websecure
        - traefik.http.routers.portainer.priority=1

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
cat > /tmp/stack-traefik.yml <<EOF
version: "3.7"

services:
  traefik:
    image: traefik:v2.11.2
    command:
      - "--api.dashboard=true"
      - "--providers.docker.swarmMode=true"
      - "--providers.docker.endpoint=unix:///var/run/docker.sock"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=${NETWORK_NAME}"

      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.web.transport.respondingTimeouts.idleTimeout=3600"

      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.letsencryptresolver.acme.storage=/etc/traefik/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencryptresolver.acme.email=${EMAIL_LETSENCRYPT}"

      - "--log.level=DEBUG"
      - "--log.format=common"
      - "--log.filePath=/var/log/traefik/traefik.log"
      - "--accesslog=true"
      - "--accesslog.filepath=/var/log/traefik/access-log"

    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.http.middlewares.redirect-https.redirectscheme.scheme=https
        - traefik.http.middlewares.redirect-https.redirectscheme.permanent=true
        - traefik.http.routers.http-catchall.rule=Host(\`{host:.+}\`)
        - traefik.http.routers.http-catchall.entrypoints=web
        - traefik.http.routers.http-catchall.middlewares=redirect-https@docker
        - traefik.http.routers.http-catchall.priority=1

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

# Verifica se temos pelo menos 1 container "Running" em cada stack
sleep 5
P_STATUS=$(docker stack ps portainer --format "{{.CurrentState}}" 2>/dev/null | grep "Running" | wc -l)
T_STATUS=$(docker stack ps traefik --format "{{.CurrentState}}" 2>/dev/null | grep "Running" | wc -l)

if [[ "$P_STATUS" -gt 0 && "$T_STATUS" -gt 0 ]]; then
  echo -e "${GREEN}Instalação concluída com sucesso!${RESET}"
  echo -e "${INFO} - Rede interna: $NETWORK_NAME"
  echo -e "${INFO} - Nome do Servidor: $SERVER_NAME"
  echo -e "${INFO} - E-mail Let's Encrypt: $EMAIL_LETSENCRYPT"
  echo -e "${INFO} - Domínio do Portainer: https://${PORTAINER_DOMAIN}"
  echo -e "${BLUE}Para verificar detalhes:\n  docker stack ps portainer\n  docker stack ps traefik${RESET}"
else
  log_error "Um ou mais serviços não estão em Running."
  echo "Verifique com: docker stack ps portainer / traefik"
  echo "Corrija o problema e tente novamente."
  exit 1
fi
