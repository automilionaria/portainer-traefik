#!/bin/bash
set -e

############################################################
#               AUTO-INSTALADOR PORTAINER+TRAEFIK (v2)
#               Swarm | ACME robusto | Cloudflare DNS-01
############################################################

# ----- Cores -----
RESET="\e[0m"; GREEN="\e[32m"; BLUE="\e[34m"; YELLOW="\e[33m"; WHITE="\e[97m"
OK="[ ${GREEN}OK${RESET} ]"; INFO="[ ${BLUE}INFO${RESET} ]"; ERROR="[ \e[31mERRO${RESET} ]"
log_ok(){ echo -e "${OK} - $1"; }
log_info(){ echo -e "${INFO} - $1"; }
log_error(){ echo -e "${ERROR} - $1"; }

clear
echo -e "${GREEN}== Portainer + Traefik v2 (Swarm) ==${RESET}"
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
# 2/18 - Pacotes base (sudo, git, python3, curl, dig/chrony)
#############################################
print_step "Instalando dependências (sudo, git, python3, curl, dnsutils, chrony)"
apt-get install -y sudo git python3 curl dnsutils chrony jq
systemctl enable --now chronyd || systemctl enable --now chrony || true
timedatectl set-ntp true || true
sleep 1
log_ok "Dependências OK (NTP ativo)"

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
  echo -e "${INFO} Usaremos DNS-01 (Cloudflare). Gere um API Token com Zone.DNS:Edit e cole abaixo."
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
# 6/18 - Checagens de portas 80/443
#############################################
print_step "Checando portas 80/443"
if ss -ltn '( sport = :80 or sport = :443 )' | grep -E 'LISTEN'; then
  log_error "Porta 80 e/ou 443 em uso. Pare o serviço antes (nginx/apache) e rode de novo."; exit 1
fi
log_ok "Portas livres"; sleep 1

#############################################
# 7/18 - Checagem DNS e alerta AAAA
#############################################
print_step "Checando DNS (A/AAAA) do domínio"
A_IP=$(dig +short A $PORTAINER_DOMAIN | tail -n1)
AAAA_IP=$(dig +short AAAA $PORTAINER_DOMAIN | tail -n1)
PUB_IP=$(curl -sS ipv4.icanhazip.com || true)
echo -e "${INFO} A=$A_IP | AAAA=${AAAA_IP:-<nenhum>} | IP público=$PUB_IP"
if [[ -n "$AAAA_IP" && "$AAAA_IP" != "::1" ]]; then
  echo -e "${YELLOW}Atenção:${RESET} Existe AAAA (IPv6). Se seu host NÃO tem Traefik no IPv6, o navegador pode preferir IPv6 e falhar."
  echo -e "Sugestão: remova temporariamente AAAA ou garanta Traefik ouvindo IPv6 no mesmo host."
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
version: "3.7"
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
        - traefik.docker.network=${NETWORK_NAME}

networks:
  ${NETWORK_NAME}:
    external: true

volumes:
  portainer_data:
    external: true
EOF
log_ok "stack-portainer.yml pronto"; sleep 1

#############################################
# 11/18 - ACME: modo (HTTP-01 x DNS-01)
#############################################
print_step "Montando configuração ACME"
if [[ "$CF_PROXY" =~ ^[Ss]$ ]]; then
  ACME_BLOCK=$(cat <<'EOT'
      - "--certificatesresolvers.letsencryptresolver.acme.dnschallenge=true"
      - "--certificatesresolvers.letsencryptresolver.acme.dnschallenge.provider=cloudflare"
      - "--certificatesresolvers.letsencryptresolver.acme.dnschallenge.delaybeforecheck=30"
EOT
)
  ENV_BLOCK=$'    environment:\n      CF_DNS_API_TOKEN: '"\"$CF_TOKEN\""
  log_info "Cloudflare DNS-01 habilitado"
else
  ACME_BLOCK=$(cat <<'EOT'
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web"
EOT
)
  ENV_BLOCK=""
  log_info "HTTP-01 habilitado (precisa porta 80 direta e sem proxy)"
fi
sleep 1

#############################################
# 12/18 - Stack Traefik (v2.11.2) + logs em stdout
#############################################
print_step "Gerando stack Traefik"
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

      - "--entrypoints.web.forwardedHeaders.insecure=true"
      - "--entrypoints.websecure.forwardedHeaders.insecure=true"

      - "--serversTransport.forwardingTimeouts.dialTimeout=30s"
      - "--serversTransport.forwardingTimeouts.responseHeaderTimeout=60s"
      - "--serversTransport.forwardingTimeouts.idleConnTimeout=90s"

      - "--certificatesresolvers.letsencryptresolver.acme.email=${EMAIL_LETSENCRYPT}"
      - "--certificatesresolvers.letsencryptresolver.acme.storage=/etc/traefik/letsencrypt/acme.json"
${ACME_BLOCK}

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
        - traefik.http.middlewares.redirect-https.redirectscheme.scheme=https
        - traefik.http.middlewares.redirect-https.redirectscheme.permanent=true
        - traefik.http.routers.http-catchall.rule=Host(\`{host:.+}\`)
        - traefik.http.routers.http-catchall.entrypoints=web
        - traefik.http.routers.http-catchall.middlewares=redirect-https@docker

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

  # Serviço whoami TEMPORÁRIO pra smoke test do roteamento (remova depois se quiser)
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
        - traefik.docker.network=${NETWORK_NAME}

volumes:
  volume_swarm_shared:
    external: true
  volume_swarm_certificates:
    external: true

networks:
  ${NETWORK_NAME}:
    external: true
EOF
log_ok "stack-traefik.yml pronto"; sleep 1

#############################################
# 13/18 - Deploy Portainer
#############################################
print_step "Deploy Portainer"
docker stack deploy -c /tmp/stack-portainer.yml portainer
sleep 2

#############################################
# 14/18 - Deploy Traefik
#############################################
print_step "Deploy Traefik"
docker stack deploy -c /tmp/stack-traefik.yml traefik
sleep 5

#############################################
# 15/18 - Espera inicial e verificação
#############################################
print_step "Verificando serviços (até 90s)"
MAX_WAIT=90; ELAPSED=0
until \
  [ "$(docker stack ps portainer --format '{{.CurrentState}}' | grep -c Running)" -gt 0 ] && \
  [ "$(docker stack ps traefik --format '{{.CurrentState}}'   | grep -c Running)" -gt 0 ]; do
  sleep 3; ELAPSED=$((ELAPSED+3)); [ $ELAPSED -ge $MAX_WAIT ] && break
done

#############################################
# 16/18 - Status e dicas
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
echo -e "  Rede:        ${NETWORK_NAME}"
echo -e "  Servidor:    ${SERVER_NAME}"
echo -e "  Portainer:   https://${PORTAINER_DOMAIN}"
echo -e "  Whoami (tmp): https://whoami.${PORTAINER_DOMAIN}  (para smoke test)"
echo "========================================"
echo
echo -e "${INFO} Se usa Cloudflare proxy (laranja), DNS-01 está ativo."
echo -e "${INFO} Se usa HTTP-01, mantenha a porta 80 aberta e o proxy desativado (nuvem cinza) até emitir."
echo

#############################################
# 18/18 - Instruções de debug rápido
#############################################
print_step "Dicas rápidas de diagnóstico"
echo "- Logs Traefik:    docker service logs traefik_traefik -f --since 15m"
echo "- Logs Portainer:  docker service logs portainer_portainer -f --since 15m"
echo "- ACME no volume:  docker run --rm -v volume_swarm_certificates:/etc/traefik/letsencrypt bash:5.2 bash -lc 'ls -l /etc/traefik/letsencrypt; stat -c \"%a %n\" /etc/traefik/letsencrypt/acme.json'"
echo "- Ver AAAA/domínio: dig +short A ${PORTAINER_DOMAIN}; dig +short AAAA ${PORTAINER_DOMAIN}"
echo "- Teste whoami:    curl -I https://whoami.${PORTAINER_DOMAIN}"
