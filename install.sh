#!/bin/bash
set -e

############################################################
#      PORTAINER + TRAEFIK v2.11.2 (SWARM, HTTP-01 ACME)
#      Sem proxy Cloudflare (nuvem cinza) | 80/443 abertos
############################################################

# -------------- Estilos --------------
RESET="\e[0m"; GREEN="\e[32m"; BLUE="\e[34m"; YELLOW="\e[33m"; WHITE="\e[97m"
OK="[ ${GREEN}OK${RESET} ]"; INFO="[ ${BLUE}INFO${RESET} ]"; ERROR="[ \e[31mERRO${RESET} ]"
log_ok(){ echo -e "${OK} - $1"; }
log_info(){ echo -e "${INFO} - $1"; }
log_error(){ echo -e "${ERROR} - $1"; }

clear
echo -e "${GREEN}== Portainer + Traefik v2 (Swarm, HTTP-01) ==${RESET}"
sleep 1

TOTAL_STEPS=18
STEP=1
print_step(){ echo -e "${STEP}/${TOTAL_STEPS} - ${OK} - $1"; STEP=$((STEP+1)); }

#############################################
# 1/18 - Atualizar Sistema
#############################################
print_step "Atualizando sistema"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y && apt-get upgrade -y
log_ok "Sistema OK"; sleep 1

#############################################
# 2/18 - Pacotes base
#############################################
print_step "Instalando dependências (sudo, git, python3, curl, dnsutils, chrony, jq)"
apt-get install -y sudo git python3 curl dnsutils chrony jq || true
(systemctl enable --now chronyd || systemctl enable --now chrony || true) >/dev/null 2>&1 || true
timedatectl set-ntp true >/dev/null 2>&1 || true
log_ok "Dependências OK (NTP ativo)"; sleep 1

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

# normaliza domínio
PORTAINER_DOMAIN=${PORTAINER_DOMAIN#http://}
PORTAINER_DOMAIN=${PORTAINER_DOMAIN#https://}
PORTAINER_DOMAIN=${PORTAINER_DOMAIN%/}

echo
echo "---- Confirmação ----"
echo "Rede: $NETWORK_NAME"
echo "Servidor: $SERVER_NAME"
echo "E-mail ACME: $EMAIL_LETSENCRYPT"
echo "Domínio Portainer: https://$PORTAINER_DOMAIN"
echo "---------------------"
read -p "Está tudo correto? (s/n): " OKCONF
[[ "$OKCONF" =~ ^[Ss]$ ]] || { log_error "Cancelado."; exit 1; }

#############################################
# 6/18 - Portas 80/443
#############################################
print_step "Checando se as portas 80/443 estão livres"
if ss -ltn '( sport = :80 or sport = :443 )' | grep -E 'LISTEN' >/dev/null; then
  echo
  ss -ltnp | egrep ':80|:443' || true
  echo
  log_error "Porta 80 e/ou 443 em uso. Pare nginx/apache/outros e rode novamente."
  exit 1
fi
log_ok "Portas livres"; sleep 1

#############################################
# 7/18 - DNS (A/AAAA)
#############################################
print_step "Checando DNS (A/AAAA) do domínio"
A_IP=$(dig +short A "$PORTAINER_DOMAIN" | tail -n1)
AAAA_IP=$(dig +short AAAA "$PORTAINER_DOMAIN" | tail -n1)
PUB_IP=$(curl -sS ipv4.icanhazip.com || true)
echo -e "${INFO} A=${A_IP:-<nenhum>} | AAAA=${AAAA_IP:-<nenhum>} | IP público=$PUB_IP"
if [[ -z "$A_IP" ]]; then
  log_error "O domínio não tem registro A apontando para este servidor. Ajuste o DNS e rode de novo."
  exit 1
fi
if [[ "$A_IP" != "$PUB_IP" ]]; then
  echo -e "${YELLOW}Atenção:${RESET} Registro A ($A_IP) difere do IP público ($PUB_IP)."
fi
if [[ -n "$AAAA_IP" && "$AAAA_IP" != "::1" ]]; then
  echo -e "${YELLOW}Atenção:${RESET} Existe AAAA (IPv6). Se o host NÃO atende IPv6, o browser pode preferir IPv6 e falhar."
  echo -e "Sugestão: remova temporariamente AAAA para emissão HTTP-01, ou ative IPv6 real."
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
# 11/18 - Stack Traefik v2 (HTTP-01)
#############################################
print_step "Gerando stack Traefik v2 (HTTP-01, sem proxy)"
cat > /tmp/stack-traefik.yml <<EOF
version: "3.8"
services:
  traefik:
    image: traefik:v2.11.2
    command:
      # Provider Swarm (v2)
      - "--api.dashboard=true"
      - "--providers.docker.swarmMode=true"
      - "--providers.docker.endpoint=unix:///var/run/docker.sock"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=${NETWORK_NAME}"

      # Entrypoints (HTTP->HTTPS)
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

      # ACME HTTP-01
      - "--certificatesresolvers.letsencryptresolver.acme.email=${EMAIL_LETSENCRYPT}"
      - "--certificatesresolvers.letsencryptresolver.acme.storage=/etc/traefik/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web"

      # Logs
      - "--log.level=INFO"
      - "--accesslog=true"

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

        # Redirecionar HTTP -> HTTPS (provider docker)
        - traefik.http.middlewares.redirect-https.redirectscheme.scheme=https
        - traefik.http.middlewares.redirect-https.redirectscheme.permanent=true
        - traefik.http.routers.http-catchall.rule=Host(\`{host:.+}\`)
        - traefik.http.routers.http-catchall.entrypoints=web
        - traefik.http.routers.http-catchall.middlewares=redirect-https@docker

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

  # Serviço whoami TEMPORÁRIO para smoke test
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
# 12/18 - Deploy Portainer
#############################################
print_step "Deploy Portainer"
docker stack deploy -c /tmp/stack-portainer.yml portainer
sleep 2

#############################################
# 13/18 - Deploy Traefik v2
#############################################
print_step "Deploy Traefik"
docker stack deploy -c /tmp/stack-traefik.yml traefik
sleep 5

#############################################
# 14/18 - Espera e verificação
#############################################
print_step "Verificando serviços (até 90s)"
MAX_WAIT=90; ELAPSED=0
until \
  [ "$(docker stack ps portainer --format '{{.CurrentState}}' | grep -c Running)" -gt 0 ] && \
  [ "$(docker stack ps traefik --format '{{.CurrentState}}'   | grep -c Running)" -gt 0 ]; do
  sleep 3; ELAPSED=$((ELAPSED+3)); [ $ELAPSED -ge $MAX_WAIT ] && break
done

#############################################
# 15/18 - Status atual
#############################################
print_step "Status atual"
docker service ls | egrep 'traefik|portainer|whoami' || true

#############################################
# 16/18 - Saída amigável
#############################################
print_step "Concluído"
echo
echo "========================================"
echo -e "  ${GREEN}Instalação concluída${RESET}"
echo -e "  Rede:        ${NETWORK_NAME}"
echo -e "  Servidor:    ${SERVER_NAME}"
echo -e "  Portainer:   https://${PORTAINER_DOMAIN}"
echo -e "  Whoami (tmp): https://whoami.${PORTAINER_DOMAIN}  (smoke test)"
echo "========================================"
echo
echo -e "${INFO} HTTP-01 requer: porta 80 aberta para Internet e DNS \e[1msem proxy\e[0m (nuvem cinza).
${INFO} Se houver AAAA (IPv6) e o host não atender IPv6, remova o AAAA temporariamente para emissão."
echo

#############################################
# 17/18 - Dicas rápidas de diagnóstico
#############################################
print_step "Dicas rápidas de diagnóstico"
echo "- Logs Traefik:    docker service logs traefik_traefik -f --since 15m"
echo "- Logs Portainer:  docker service logs portainer_portainer -f --since 15m"
echo "- ACME volume:     docker run --rm -v volume_swarm_certificates:/etc/traefik/letsencrypt bash:5.2 bash -lc 'ls -l /etc/traefik/letsencrypt; stat -c \"%a %n\" /etc/traefik/letsencrypt/acme.json'"
echo "- Conferir portas: ss -ltnp | egrep ':80|:443'"
echo "- Conferir DNS:    dig +short A ${PORTAINER_DOMAIN}; dig +short AAAA ${PORTAINER_DOMAIN}"

#############################################
# 18/18 - Nota final
#############################################
print_step "Nota"
echo "Se precisar manter AAAA/Cloudflare proxy, migre para DNS-01 (Cloudflare) — posso te passar a variação."
