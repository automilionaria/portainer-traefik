#!/bin/bash
set -e

############################################################
#      AUTO-INSTALADOR PORTAINER + TRAEFIK v3 (SWARM)
#      ACME robusto | HTTP-01 ou DNS-01 (Cloudflare)
############################################################

# ----- Cores -----
RESET="\e[0m"; GREEN="\e[32m"; BLUE="\e[34m"; YELLOW="\e[33m"; WHITE="\e[97m"
OK="[ ${GREEN}OK${RESET} ]"; INFO="[ ${BLUE}INFO${RESET} ]"; ERROR="[ \e[31mERRO${RESET} ]"
log_ok(){ echo -e "${OK} - $1"; }
log_info(){ echo -e "${INFO} - $1"; }
log_error(){ echo -e "${ERROR} - $1"; }

clear
echo -e "${GREEN}== Portainer + Traefik v3 (Swarm) ==${RESET}"
sleep 1

TOTAL_STEPS=18
STEP=1
print_step(){ echo -e "${STEP}/${TOTAL_STEPS} - ${OK} - $1"; STEP=$((STEP+1)); }

#############################################
# 1/18 - Update/upgrade
#############################################
print_step "Atualizando sistema"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y && apt-get upgrade -y
log_ok "Sistema OK"; sleep 1

#############################################
# 2/18 - Pacotes base
#############################################
print_step "Instalando dependências (sudo, git, python3, curl, dnsutils, chrony, jq)"
apt-get install -y sudo git python3 curl dnsutils chrony jq
systemctl enable --now chronyd || systemctl enable --now chrony || true
timedatectl set-ntp true || true
log_ok "Dependências + NTP OK"; sleep 1

#############################################
# 3/18 - Docker
#############################################
print_step "Verificando/instalando Docker"
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
fi
log_ok "Docker OK"; sleep 1

#############################################
# 4/18 - Swarm
#############################################
print_step "Inicializando Docker Swarm (se necessário)"
SWARM_ACTIVE=$(docker info 2>/dev/null | awk '/Swarm/{print $2}')
if [ "$SWARM_ACTIVE" != "active" ]; then
  IP=$(hostname -I | awk '{print $1}')
  docker swarm init --advertise-addr "$IP" || true
  SWARM_ACTIVE_AGAIN=$(docker info 2>/dev/null | awk '/Swarm/{print $2}')
  if [ "$SWARM_ACTIVE_AGAIN" != "active" ]; then
    log_error "Falha no Swarm. Verifique IP público e tente novamente."; exit 1
  fi
fi
log_ok "Swarm ativo"; sleep 1

#############################################
# 5/18 - Entrada de dados
#############################################
print_step "Coletando dados"
read -p $'\e[33mNome da rede overlay:\e[0m ' NETWORK_NAME
read -p $'\e[33mNome do servidor (label):\e[0m ' SERVER_NAME
read -p $'\e[33mE-mail para Let\'s Encrypt:\e[0m ' EMAIL_LETSENCRYPT
read -p $'\e[33mDomínio do Portainer (ex: portainer.seudominio.com):\e[0m ' PORTAINER_DOMAIN
read -p $'\e[33mSeu domínio está proxificado pela Cloudflare (nuvem laranja)? (s/n):\e[0m ' CF_PROXY

PORTAINER_DOMAIN=${PORTAINER_DOMAIN#http://}
PORTAINER_DOMAIN=${PORTAINER_DOMAIN#https://}
PORTAINER_DOMAIN=${PORTAINER_DOMAIN%/}

CF_TOKEN=""
if [[ "$CF_PROXY" =~ ^[Ss]$ ]]; then
  echo -e "${INFO} Usaremos DNS-01 (Cloudflare). Gere um API Token com Zone.DNS:Edit (scoped na zona) e cole abaixo."
  read -p $'\e[33mCloudflare API Token:\e[0m ' CF_TOKEN
fi

echo
echo "---- Confirmação ----"
echo "Rede: $NETWORK_NAME"
echo "Servidor: $SERVER_NAME"
echo "E-mail ACME: $EMAIL_LETSENCRYPT"
echo "Domínio Portainer: https://$PORTAINER_DOMAIN"
echo "Cloudflare proxy: $CF_PROXY"
echo "---------------------"
read -p "Está tudo correto? (s/n): " OKCONF
[[ "$OKCONF" =~ ^[Ss]$ ]] || { log_error "Cancelado."; exit 1; }

#############################################
# 6/18 - Portas 80/443
#############################################
print_step "Checando se as portas 80/443 estão livres"
if ss -ltn '( sport = :80 or sport = :443 )' | grep -E 'LISTEN'; then
  log_error "Porta 80 e/ou 443 em uso. Pare nginx/apache/outros e rode novamente."; exit 1
fi
log_ok "Portas livres"; sleep 1

#############################################
# 7/18 - DNS e alerta AAAA
#############################################
print_step "Checando DNS (A/AAAA) do domínio"
A_IP=$(dig +short A $PORTAINER_DOMAIN | tail -n1)
AAAA_IP=$(dig +short AAAA $PORTAINER_DOMAIN | tail -n1)
PUB_IP=$(curl -sS ipv4.icanhazip.com || true)
echo -e "${INFO} A=$A_IP | AAAA=${AAAA_IP:-<nenhum>} | IP público=$PUB_IP"
if [[ -n "$AAAA_IP" && "$AAAA_IP" != "::1" ]]; then
  echo -e "${YELLOW}Atenção:${RESET} Existe AAAA (IPv6). Se seu host NÃO atende IPv6, o browser pode preferir IPv6 e falhar."
fi
sleep 1

#############################################
# 8/18 - Volumes e rede
#############################################
print_step "Criando volumes e rede"
docker volume create portainer_data >/dev/null
docker volume create volume_swarm_shared >/dev/null
docker volume create volume_swarm_certificates >/dev/null
docker network create --driver overlay --attachable "$NETWORK_NAME" || true
log_ok "Volumes/rede OK"; sleep 1

#############################################
# 9/18 - Preparar acme.json 600
#############################################
print_step "Preparando acme.json (600)"
docker run --rm -v volume_swarm_certificates:/etc/traefik/letsencrypt bash:5.2 \
  bash -lc 'touch /etc/traefik/letsencrypt/acme.json && chmod 600 /etc/traefik/letsencrypt/acme.json'
log_ok "acme.json pronto"; sleep 1

#############################################
# 10/18 - Stack Portainer
#############################################
print_step "Gerando stack Portainer"
cat > /tmp/stack-portainer.yml <<EOF
version: "3.8"
services:
  agent:
    image: portainer/agent:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
    networks: [ ${NETWORK_NAME} ]
    deploy:
      mode: global
      placement:
        constraints: [ "node.platform.os == linux" ]

  portainer:
    image: portainer/portainer-ce:latest
    command: -H tcp://tasks.agent:9001 --tlsskipverify
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks: [ ${NETWORK_NAME} ]
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: [ "node.role == manager" ]
      labels:
        - traefik.enable=true
        - traefik.http.routers.portainer.rule=Host(\`${PORTAINER_DOMAIN}\`)
        - traefik.http.routers.portainer.entrypoints=websecure
        - traefik.http.routers.portainer.tls.certresolver=letsencryptresolver
        - traefik.http.services.portainer.loadbalancer.server.port=9000
        - traefik.swarm.network=${NETWORK_NAME}

networks:
  ${NETWORK_NAME}:
    external: true

volumes:
  portainer_data:
    external: true
EOF
log_ok "stack-portainer.yml pronto"; sleep 1

#############################################
# 11/18 - ACME blocks (HTTP-01 x DNS-01)
#############################################
print_step "Montando configuração ACME para Traefik v3"
if [[ "$CF_PROXY" =~ ^[Ss]$ ]]; then
  ACME_CHALLENGE_BLOCK=$(cat <<'EOT'
      - "--certificatesresolvers.letsencryptresolver.acme.dnschallenge=true"
      - "--certificatesresolvers.letsencryptresolver.acme.dnschallenge.provider=cloudflare"
      - "--certificatesresolvers.letsencryptresolver.acme.dnschallenge.delaybeforecheck=30"
EOT
)
  ENV_BLOCK=$'    environment:\n      CF_DNS_API_TOKEN: '"\"$CF_TOKEN\""
  log_info "DNS-01 (Cloudflare) habilitado"
else
  ACME_CHALLENGE_BLOCK=$(cat <<'EOT'
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web"
EOT
)
  ENV_BLOCK=""
  log_info "HTTP-01 habilitado (porta 80 direta, sem proxy)"
fi
sleep 1

#############################################
# 12/18 - Stack Traefik v3 (provider: Swarm)
#############################################
print_step "Gerando stack Traefik v3 (Swarm provider)"
cat > /tmp/stack-traefik.yml <<EOF
version: "3.8"
services:
  traefik:
    image: traefik:v3.1
    command:
      - "--api.dashboard=true"

      # Provider SWARM (v3)
      - "--providers.swarm=true"
      - "--providers.swarm.endpoint=unix:///var/run/docker.sock"
      - "--providers.swarm.exposedByDefault=false"
      - "--providers.swarm.network=${NETWORK_NAME}"

      # Entrypoints
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
      - "--entrypoints.websecure.address=:443"

      # Encaminhamento de headers de IP real
      - "--entrypoints.web.forwardedHeaders.insecure=true"
      - "--entrypoints.websecure.forwardedHeaders.insecure=true"

      # Timeouts upstream
      - "--serversTransport.forwardingTimeouts.dialTimeout=30s"
      - "--serversTransport.forwardingTimeouts.responseHeaderTimeout=60s"
      - "--serversTransport.forwardingTimeouts.idleConnTimeout=90s"

      # ACME (com bloco específico abaixo)
      - "--certificatesresolvers.letsencryptresolver.acme.email=${EMAIL_LETSENCRYPT}"
      - "--certificatesresolvers.letsencryptresolver.acme.storage=/etc/traefik/letsencrypt/acme.json"
${ACME_CHALLENGE_BLOCK}

      # Logs
      - "--log.level=INFO"
      - "--accesslog=true"
${ENV_BLOCK}
    deploy:
      placement:
        constraints: [ "node.role == manager" ]
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 5
        window: 120s
      labels:
        - traefik.enable=true

        # Redirecionar HTTP -> HTTPS (provider: swarm)
        - traefik.http.middlewares.redirect-https.redirectscheme.scheme=https
        - traefik.http.middlewares.redirect-https.redirectscheme.permanent=true
        - traefik.http.routers.http-catchall.rule=Host(\`{host:.+}\`)
        - traefik.http.routers.http-catchall.entrypoints=web
        - traefik.http.routers.http-catchall.middlewares=redirect-https@swarm

        # Middlewares globais úteis
        - traefik.http.middlewares.compress.compress=true
        - traefik.http.middlewares.buffering.buffering.maxRequestBodyBytes=20000000
        - traefik.http.middlewares.buffering.buffering.maxResponseBodyBytes=20000000
        - traefik.http.middlewares.buffering.buffering.memRequestBodyBytes=2097152
        - traefik.http.middlewares.buffering.buffering.retryExpression=IsNetworkError() && Attempts() <= 2
        - traefik.http.middlewares.ratelimit-public.ratelimit.period=1m
        - traefik.http.middlewares.ratelimit-public.ratelimit.average=120
        - traefik.http.middlewares.ratelimit-public.ratelimit.burst=240
        - traefik.http.middlewares.secure-headers.headers.referrerPolicy=no-referrer-when-downgrade
        - traefik.http.middlewares.secure-headers.headers.stsSeconds=31536000
        - traefik.http.middlewares.secure-headers.headers.stsIncludeSubdomains=true
        - traefik.http.middlewares.secure-headers.headers.stsPreload=true
        - traefik.http.middlewares.secure-headers.headers.browserXssFilter=true
        - traefik.http.middlewares.secure-headers.headers.contentTypeNosniff=true

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

    networks: [ ${NETWORK_NAME} ]

  # Serviço whoami TEMPORÁRIO para smoke test (remova depois)
  whoami:
    image: traefik/whoami:v1.10
    networks: [ ${NETWORK_NAME} ]
    deploy:
      replicas: 1
      labels:
        - traefik.enable=true
        - traefik.http.routers.whoami.rule=Host(\`whoami.${PORTAINER_DOMAIN}\`)
        - traefik.http.routers.whoami.entrypoints=websecure
        - traefik.http.routers.whoami.tls.certresolver=letsencryptresolver
        - traefik.http.services.whoami.loadbalancer.server.port=80
        - traefik.swarm.network=${NETWORK_NAME}

volumes:
  volume_swarm_shared:
    external: true
  volume_swarm_certificates:
    external: true

networks:
  ${NETWORK_NAME}:
    external: true
EOF
log_ok "stack-traefik.yml (v3) pronto"; sleep 1

#############################################
# 13/18 - Deploy Portainer
#############################################
print_step "Deploy Portainer"
docker stack deploy -c /tmp/stack-portainer.yml portainer
sleep 2

#############################################
# 14/18 - Deploy Traefik v3
#############################################
print_step "Deploy Traefik v3"
docker stack deploy -c /tmp/stack-traefik.yml traefik
sleep 5

#############################################
# 15/18 - Espera e verificação
#############################################
print_step "Verificando serviços (até 90s)"
MAX_WAIT=90; ELAPSED=0
until \
  [ "$(docker stack ps portainer --format '{{.CurrentState}}' | grep -c Running)" -gt 0 ] && \
  [ "$(docker stack ps traefik --format '{{.CurrentState}}'   | grep -c Running)" -gt 0 ]; do
  sleep 3; ELAPSED=$((ELAPSED+3)); [ $ELAPSED -ge $MAX_WAIT ] && break
done

#############################################
# 16/18 - Status atual
#############################################
print_step "Status atual"
docker service ls | egrep 'traefik|portainer|whoami' || true

#############################################
# 17/18 - Saída amigável
#############################################
print_step "Concluído"
echo
echo "========================================"
echo -e "  ${GREEN}Instalação concluída${RESET}"
echo -e "  Rede:         ${NETWORK_NAME}"
echo -e "  Servidor:     ${SERVER_NAME}"
echo -e "  Portainer:    https://${PORTAINER_DOMAIN}"
echo -e "  Whoami (tmp): https://whoami.${PORTAINER_DOMAIN}  (smoke test)"
echo "========================================"
echo
echo -e "${INFO} Se usa Cloudflare proxy (laranja), DNS-01 está ativo."
echo -e "${INFO} Se usa HTTP-01, mantenha a porta 80 aberta e proxy desativado até emitir."
echo

#############################################
# 18/18 - Dicas rápidas (v3)
#############################################
print_step "Dicas rápidas de diagnóstico"
echo "- Logs Traefik:    docker service logs traefik_traefik -f --since 15m"
echo "- Logs Portainer:  docker service logs portainer_portainer -f --since 15m"
echo "- ACME no volume:  docker run --rm -v volume_swarm_certificates:/etc/traefik/letsencrypt bash:5.2 bash -lc 'ls -l /etc/traefik/letsencrypt; stat -c \"%a %n\" /etc/traefik/letsencrypt/acme.json'"
echo "- Ver AAAA/domínio: dig +short A ${PORTAINER_DOMAIN}; dig +short AAAA ${PORTAINER_DOMAIN}"
echo "- Teste whoami:    curl -I https://whoami.${PORTAINER_DOMAIN}"
