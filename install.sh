#!/bin/bash
############################################################
#        AUTO-INSTALADOR PORTAINER + TRAEFIK (2025)
#         por Minha Automação MilionárIA ⚙️💡
############################################################

RESET="\e[0m"; GREEN="\e[32m"; BLUE="\e[34m"; WHITE="\e[97m"
OK="[ ${GREEN}OK${RESET} ]"; INFO="[ ${BLUE}INFO${RESET} ]"
ERROR="[ \e[31mERRO${RESET} ]"
log_ok(){ echo -e "${OK} - $1"; }
log_info(){ echo -e "${INFO} - $1"; }
log_error(){ echo -e "${ERROR} - $1"; }

clear
echo -e "${GREEN}
┌─────────────────────────────────────────────┐
│     AUTO-INSTALADOR PORTAINER + TRAEFIK     │
│       by Minha Automação MilionárIA 💡       │
└─────────────────────────────────────────────┘${RESET}"
sleep 1

TOTAL_STEPS=14; STEP=1
print_step(){ echo -e "${STEP}/${TOTAL_STEPS} - ${OK} - $1"; STEP=$((STEP+1)); }

# 1. Atualização
print_step "Atualizando pacotes"
sudo apt-get update -y && sudo apt-get upgrade -y || { log_error "Falha ao atualizar"; exit 1; }

# 2. Dependências
print_step "Instalando dependências"
sudo apt-get install -y sudo apt-utils curl git python3 lsof ca-certificates gnupg || { log_error "Falha nas dependências"; exit 1; }

# 3. Docker
print_step "Instalando Docker (se ausente)"
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh || { log_error "Falha Docker"; exit 1; }
fi
sudo systemctl enable docker --now; log_ok "Docker ativo"

# 4. Swarm
print_step "Inicializando Docker Swarm"
IP=$(hostname -I | awk '{print $1}')
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
  docker swarm init --advertise-addr "$IP" >/dev/null 2>&1 || true
fi
docker info | grep "Swarm"; log_ok "Swarm pronto"

# 5. Dados do usuário
print_step "Coletando informações"
read -p "Nome da rede interna (overlay): " NETWORK_NAME
read -p "Nome do servidor: " SERVER_NAME
read -p "E-mail para Let's Encrypt: " EMAIL_LETSENCRYPT
read -p "Domínio Portainer (ex: portainer.seudominio.com): " PORTAINER_DOMAIN
echo -e "${INFO} Rede: $NETWORK_NAME | Domínio: $PORTAINER_DOMAIN${RESET}"

# 6. Volumes
print_step "Criando volumes"
docker volume create portainer_data >/dev/null
docker volume create volume_swarm_certificates >/dev/null

# 7. Rede
print_step "Criando rede overlay '$NETWORK_NAME'"
docker network create --driver overlay --attachable "$NETWORK_NAME" >/dev/null 2>&1 || true

# 8. Stack Portainer
print_step "Gerando stack Portainer"
cat >/tmp/stack-portainer.yml <<EOF
version: "3.9"
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
        - "traefik.docker.network=${NETWORK_NAME}"
        - "traefik.http.middlewares=compress@docker,secureheaders@docker"
networks:
  ${NETWORK_NAME}:
    external: true
volumes:
  portainer_data:
    external: true
EOF

# 9. Stack Traefik
print_step "Gerando stack Traefik (revisada)"
sudo mkdir -p /var/lib/docker/volumes/volume_swarm_certificates/_data
sudo touch /var/lib/docker/volumes/volume_swarm_certificates/_data/acme.json
sudo chmod 600 /var/lib/docker/volumes/volume_swarm_certificates/_data/acme.json

cat >/tmp/stack-traefik.yml <<EOF
version: "3.9"
services:
  traefik:
    image: traefik:v3.1
    command:
      - "--api.dashboard=true"
      - "--providers.docker.swarmMode=true"
      - "--providers.docker.endpoint=unix:///var/run/docker.sock"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=${NETWORK_NAME}"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.web.forwardedHeaders.insecure=true"
      - "--entrypoints.websecure.forwardedHeaders.insecure=true"
      - "--certificatesresolvers.letsencryptresolver.acme.email=${EMAIL_LETSENCRYPT}"
      - "--certificatesresolvers.letsencryptresolver.acme.storage=/etc/traefik/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web"
      - "--log.level=INFO"
      - "--accesslog=true"
    deploy:
      placement:
        constraints:
          - node.role == manager
      restart_policy:
        condition: any
        delay: 10s
        max_attempts: 5
      update_config:
        failure_action: rollback
      labels:
        - "traefik.enable=true"
        - "traefik.http.middlewares.redirect-https.redirectscheme.scheme=https"
        - "traefik.http.middlewares.redirect-https.redirectscheme.permanent=true"
        - "traefik.http.routers.http-catchall.rule=HostRegexp(\`{any:.+}\`)"
        - "traefik.http.routers.http-catchall.entrypoints=web"
        - "traefik.http.routers.http-catchall.middlewares=redirect-https@docker"
        - "traefik.http.middlewares.compress.compress=true"
        - "traefik.http.middlewares.secureheaders.headers.stsSeconds=31536000"
        - "traefik.http.middlewares.secureheaders.headers.stsIncludeSubdomains=true"
        - "traefik.http.middlewares.secureheaders.headers.contentTypeNosniff=true"
        - "traefik.http.middlewares.secureheaders.headers.browserXssFilter=true"
        - "traefik.http.middlewares.secureheaders.headers.referrerPolicy=no-referrer-when-downgrade"
    ports:
      - target: 80
        published: 80
        mode: host
      - target: 443
        published: 443
        mode: host
    volumes:
      - volume_swarm_certificates:/etc/traefik/letsencrypt
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - ${NETWORK_NAME}
volumes:
  volume_swarm_certificates:
    external: true
networks:
  ${NETWORK_NAME}:
    external: true
EOF

# 10. Deploy Portainer
print_step "Deploy Portainer"
docker stack deploy -c /tmp/stack-portainer.yml portainer

# 11. Deploy Traefik
print_step "Deploy Traefik"
docker stack deploy -c /tmp/stack-traefik.yml traefik
sleep 8

# 12. Verificação
print_step "Verificando serviços"
P=$(docker stack ps portainer --format '{{.CurrentState}}' | grep -c Running)
T=$(docker stack ps traefik --format '{{.CurrentState}}' | grep -c Running)
if [[ $P -gt 0 && $T -gt 0 ]]; then
  echo -e "\n${GREEN}✅ Instalação concluída com sucesso!${RESET}"
  echo -e "${INFO} Acesse: https://${PORTAINER_DOMAIN}"
  echo -e "${INFO} E-mail Let's Encrypt: ${EMAIL_LETSENCRYPT}"
  echo -e "${INFO} Rede: ${NETWORK_NAME}"
else
  log_error "Um serviço falhou:"
  docker stack ps portainer; docker stack ps traefik
  exit 1
fi

echo -e "\n${GREEN}⚙️ Portainer + Traefik prontos!${RESET}"
echo -e "Minha Automação MilionárIA → https://automilionaria.trade"
