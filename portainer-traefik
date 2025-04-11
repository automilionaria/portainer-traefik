#!/bin/bash
# ---------------------------------------------------------------------
# Auto-instalador de Portainer + Traefik (Swarm) - Versão "um comando"
# ---------------------------------------------------------------------

OK="[ \e[32mOK\e[0m ]"
INFO="[ \e[34mINFO\e[0m ]"
ERROR="[ \e[31mERRO\e[0m ]"

function log_info() {
  echo -e "${INFO} - $1"
}
function log_ok() {
  echo -e "${OK} - $1"
}
function log_error() {
  echo -e "${ERROR} - $1"
}

# -----------------------------------------
# 1. Atualização básica do sistema
# -----------------------------------------
log_info "Fazendo update e upgrade..."
sudo apt update -y && sudo apt upgrade -y
log_ok "Update e upgrade concluídos."

# -----------------------------------------
# 2. Verificando e instalando dependências
# -----------------------------------------
# a) sudo
log_info "Verificando/Instalando sudo..."
if ! dpkg -l | grep -q sudo; then
  sudo apt install -y sudo
fi
log_ok "sudo OK."

# b) apt-utils
log_info "Verificando/Instalando apt-utils..."
if ! dpkg -l | grep -q apt-utils; then
  sudo apt install -y apt-utils
fi
log_ok "apt-utils OK."

# c) python3
log_info "Verificando/Instalando python3..."
if ! command -v python3 >/dev/null 2>&1; then
  sudo apt install -y python3
fi
log_ok "python3 OK."

# d) git
log_info "Verificando/Instalando git..."
if ! command -v git >/dev/null 2>&1; then
  sudo apt install -y git
fi
log_ok "git OK."

# e) docker
log_info "Verificando/Instalando Docker..."
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
fi
log_ok "Docker OK."

# -----------------------------------------
# 3. Inicializando Swarm se não estiver ativo
# -----------------------------------------
SWARM_ACTIVE=$(docker info 2>/dev/null | grep "Swarm" | awk '{print $2}')
if [ "$SWARM_ACTIVE" != "active" ]; then
  log_info "Inicializando Docker Swarm (não estava ativo)..."
  docker swarm init
  log_ok "Swarm inicializado."
fi

# -----------------------------------------
# 4. Coletando dados do usuário
# -----------------------------------------
echo "--------------------------------------------------"
echo "Informe os dados para configuração:"
read -p "Nome da rede interna (overlay): " NETWORK_NAME
read -p "Nome do servidor (hostname/descrição): " SERVER_NAME
read -p "E-mail para Let's Encrypt (Traefik): " EMAIL_LETSENCRYPT
read -p "Domínio para Portainer (ex.: portainer.seudominio.com): " PORTAINER_DOMAIN
echo "--------------------------------------------------"

# -----------------------------------------
# 5. Criando volumes e rede (se não existir)
# -----------------------------------------
log_info "Criando volumes para Portainer e Traefik (se não existirem)..."
docker volume create portainer_data >/dev/null 2>&1
docker volume create volume_swarm_shared >/dev/null 2>&1
docker volume create volume_swarm_certificates >/dev/null 2>&1
log_ok "Volumes OK."

log_info "Criando rede overlay '$NETWORK_NAME' (se não existir)..."
docker network create --driver overlay --attachable "$NETWORK_NAME" >/dev/null 2>&1 || true
log_ok "Rede '$NETWORK_NAME' OK."

# -----------------------------------------
# 6. Gera docker-compose para Portainer
# -----------------------------------------
log_info "Gerando stack do Portainer..."
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

log_ok "Arquivo /tmp/stack-portainer.yml criado."

# -----------------------------------------
# 7. Gera docker-compose para Traefik
# -----------------------------------------
log_info "Gerando stack do Traefik..."
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

log_ok "Arquivo /tmp/stack-traefik.yml criado."

# -----------------------------------------
# 8. Faz o deploy do Portainer e Traefik
# -----------------------------------------
log_info "Fazendo deploy do stack Portainer..."
docker stack deploy -c /tmp/stack-portainer.yml portainer

log_info "Fazendo deploy do stack Traefik..."
docker stack deploy -c /tmp/stack-traefik.yml traefik

# -----------------------------------------
# 9. Mensagem final
# -----------------------------------------
echo "------------------------------------------------------------"
log_ok "Instalação concluída!"
echo -e "${INFO} - Rede interna: ${NETWORK_NAME}"
echo -e "${INFO} - Nome do Servidor: ${SERVER_NAME}"
echo -e "${INFO} - E-mail Let's Encrypt: ${EMAIL_LETSENCRYPT}"
echo -e "${INFO} - Domínio do Portainer: https://${PORTAINER_DOMAIN}"
echo "------------------------------------------------------------"
echo "Verifique se os serviços subiram corretamente com: docker stack ps portainer e docker stack ps traefik"
echo "------------------------------------------------------------"
