#!/bin/bash
set -e

#####################################################################
#  MAM — Portainer + Traefik v2.11.2 (Docker Swarm, HTTP-01/ACME)
#  Sem proxy (Cloudflare cinza). Cert via porta 80 direta.
#  Inclui: checagens, acme.json 600, health-wait, criar admin Portainer.
#####################################################################

RESET="\e[0m"; GREEN="\e[32m"; BLUE="\e[34m"; YELLOW="\e[33m"; RED="\e[31m"; B="\e[1m"
OK="[ ${GREEN}OK${RESET} ]"; INFO="[ ${BLUE}INFO${RESET} ]"; ERR="[ ${RED}ERRO${RESET} ]"
log_ok(){ echo -e "${OK} $1"; }
log_info(){ echo -e "${INFO} $1"; }
log_err(){ echo -e "${ERR} $1"; }

TOTAL=20; STEP=1
step(){ echo -e "${STEP}/${TOTAL} - ${OK} $1"; STEP=$((STEP+1)); }

# -------- 1. Atualizações básicas / dependências --------
clear
echo -e "${GREEN}${B}== MAM: Traefik v2 + Portainer (Swarm) ==${RESET}"
step "Atualizando pacotes (apt-get update/upgrade)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y >/dev/null
apt-get upgrade -y >/dev/null || true
log_ok "Sistema atualizado"

step "Instalando deps (sudo, curl, jq, dnsutils, python3, chrony)"
apt-get install -y sudo curl jq dnsutils python3 chrony >/dev/null || true
(systemctl enable --now chrony || systemctl enable --now chronyd || true) >/dev/null 2>&1 || true
timedatectl set-ntp true >/dev/null 2>&1 || true
log_ok "Dependências OK (NTP habilitado)"

# -------- 2. Docker / Swarm --------
step "Instalando/checando Docker"
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh >/dev/null
fi
docker version >/dev/null
log_ok "Docker OK"

step "Inicializando Docker Swarm (se necessário)"
if [[ "$(docker info 2>/dev/null | awk '/Swarm/{print $2}')" != "active" ]]; then
  IP=$(hostname -I | awk '{print $1}')
  docker swarm init --advertise-addr "$IP" >/dev/null || true
fi
[[ "$(docker info 2>/dev/null | awk '/Swarm/{print $2}')" == "active" ]] || { log_err "Falha ao iniciar Swarm"; exit 1; }
log_ok "Swarm ativo"

# -------- 3. Input do usuário --------
step "Coletando dados"
read -p $'\e[33mDomínio do Portainer (ex: portainer.seudominio.com): \e[0m' PORTAINER_DOMAIN
read -p $'\e[33mUsuário do Portainer (admin): \e[0m' PORTAINER_USER
read -s -p $'\e[33mSenha do Portainer (mín. 12 chars, com @ ou _): \e[0m' PORTAINER_PASS; echo
read -p $'\e[33mNome da rede overlay (ex: mamNet): \e[0m' NETWORK_NAME
read -p $'\e[33mNome do servidor (label): \e[0m' SERVER_NAME
read -p $'\e[33mE-mail para Let\'s Encrypt (ACME): \e[0m' ACME_EMAIL

PORTAINER_DOMAIN=${PORTAINER_DOMAIN#http://}
PORTAINER_DOMAIN=${PORTAINER_DOMAIN#https://}
PORTAINER_DOMAIN=${PORTAINER_DOMAIN%/}

echo
echo "--------- Confirmação ---------"
echo "Domínio Portainer: https://${PORTAINER_DOMAIN}"
echo "Usuário Portainer: ${PORTAINER_USER}"
echo "Servidor (label):  ${SERVER_NAME}"
echo "Rede overlay:      ${NETWORK_NAME}"
echo "E-mail ACME:       ${ACME_EMAIL}"
echo "-------------------------------"
read -p "Está tudo correto? (s/n): " CONFIRM
[[ "$CONFIRM" =~ ^[Ss]$ ]] || { log_err "Cancelado."; exit 1; }

# -------- 4. Checagens de portas / DNS --------
step "Checando se as portas 80/443 estão livres"
if ss -ltn '( sport = :80 or sport = :443 )' | grep -E 'LISTEN' >/dev/null; then
  ss -ltnp | egrep ':80|:443' || true
  log_err "Porta 80/443 em uso. Pare nginx/apache/outros e rode de novo."
  exit 1
fi
log_ok "Portas 80/443 livres"

step "Checando DNS do domínio (A/AAAA)"
A_IP=$(dig +short A "$PORTAINER_DOMAIN" | tail -n1)
AAAA_IP=$(dig +short AAAA "$PORTAINER_DOMAIN" | tail -n1)
PUB_IP=$(curl -sS ipv4.icanhazip.com || true)
log_info "A=${A_IP:-<nenhum>} | AAAA=${AAAA_IP:-<nenhum>} | IP público=${PUB_IP:-<indisponível>}"
[[ -n "$A_IP" ]] || { log_err "Sem registro A no domínio. Aponte o A para o IP público."; exit 1; }
if [[ -n "$AAAA_IP" && "$AAAA_IP" != "::1" ]]; then
  echo -e "${YELLOW}Atenção:${RESET} Existe AAAA. Se seu host NÃO atende IPv6, remova o AAAA até a emissão do certificado."
fi
[[ "$A_IP" == "$PUB_IP" ]] || echo -e "${YELLOW}Aviso:${RESET} A ($A_IP) difere do IP público ($PUB_IP)."

# -------- 5. Rede/volumes e acme.json --------
step "Criando rede overlay e volumes"
docker network create --driver overlay --attachable "$NETWORK_NAME" >/dev/null 2>&1 || true
docker volume create portainer_data >/dev/null 2>&1 || true
docker volume create volume_swarm_certificates >/dev/null 2>&1 || true
log_ok "Rede/volumes OK"

step "Preparando acme.json (perm 600) no volume"
docker run --rm -v volume_swarm_certificates:/etc/traefik/letsencrypt bash:5.2 bash -lc \
  'mkdir -p /etc/traefik/letsencrypt && touch /etc/traefik/letsencrypt/acme.json && chmod 600 /etc/traefik/letsencrypt/acme.json'
log_ok "acme.json pronto"

# -------- 6. Stacks YAML --------
step "Gerando stack do Traefik (v2.11.2, HTTP-01)"
cat > /tmp/stack-traefik.yml <<EOF
version: "3.8"
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
      - "--certificatesresolvers.letsencryptresolver.acme.email=${ACME_EMAIL}"
      - "--certificatesresolvers.letsencryptresolver.acme.storage=/etc/traefik/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencryptresolver.acme.httpchallenge.entrypoint=web"
      - "--log.level=INFO"
      - "--accesslog=true"
    deploy:
      placement:
        constraints: [ "node.role == manager" ]
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 5
        window: 2m
      labels:
        - traefik.enable=true
        - traefik.http.middlewares.redirect-https.redirectscheme.scheme=https
        - traefik.http.middlewares.redirect-https.redirectscheme.permanent=true
        - traefik.http.routers.http-catchall.rule=Host(\`{host:.+}\`)
        - traefik.http.routers.http-catchall.entrypoints=web
        - traefik.http.routers.http-catchall.middlewares=redirect-https@docker
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - volume_swarm_certificates:/etc/traefik/letsencrypt
    ports:
      - target: 80
        published: 80
        mode: host
      - target: 443
        published: 443
        mode: host
    networks: [ ${NETWORK_NAME} ]
networks:
  ${NETWORK_NAME}:
    external: true
volumes:
  volume_swarm_certificates:
    external: true
EOF
log_ok "stack-traefik.yml pronto"

step "Gerando stack do Portainer (atrás do Traefik)"
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
log_ok "stack-portainer.yml pronto"

# -------- 7. Deploy e waits --------
step "Deploy Traefik"
docker stack deploy -c /tmp/stack-traefik.yml traefik >/dev/null

# Espera Traefik subir (task Running) e socket respondendo
step "Aguardando Traefik ficar online (até 5 min)"
TRIES=100
until docker service ls | grep -q "traefik_traefik"; do sleep 3; done
until [[ "$(docker service ps traefik_traefik --format '{{.CurrentState}}' | grep -c Running)" -ge 1 ]]; do
  sleep 3; TRIES=$((TRIES-1)); [[ $TRIES -le 0 ]] && { log_err "Traefik não ficou Running"; exit 1; }
done
log_ok "Traefik Running"

step "Deploy Portainer"
docker stack deploy -c /tmp/stack-portainer.yml portainer >/dev/null

# -------- 8. Aguarda HTTPS responder e cria admin --------
step "Aguardando https://${PORTAINER_DOMAIN} responder (emitir cert)"
# Vamos tentar até 5 minutos. Primeiro aceita self-signed -k, depois confere sem -k.
TIMEOUT=100
until curl -fsS -k "https://${PORTAINER_DOMAIN}/api/status" >/dev/null 2>&1; do
  sleep 3; TIMEOUT=$((TIMEOUT-1)); [[ $TIMEOUT -le 0 ]] && break
done

# tenta sem -k (cert válido). Se falhar, ainda cria conta com -k para não travar.
if curl -fsS "https://${PORTAINER_DOMAIN}/api/status" >/dev/null 2>&1; then
  log_ok "Portainer responde com TLS válido"
  CURL_TLS="curl -fsS"
else
  echo -e "${YELLOW}Aviso:${RESET} TLS ainda não validado pelo SO. Prosseguindo com -k temporariamente."
  CURL_TLS="curl -fsS -k"
fi

# cria admin se ainda não inicializado
step "Criando conta admin no Portainer (se necessário)"
if $CURL_TLS "https://${PORTAINER_DOMAIN}/api/status" | jq -e '.Authentication' >/dev/null 2>&1; then
  INIT_PAYLOAD=$(jq -n --arg u "$PORTAINER_USER" --arg p "$PORTAINER_PASS" '{Username:$u, Password:$p}')
  $CURL_TLS -H "Content-Type: application/json" -d "$INIT_PAYLOAD" \
    "https://${PORTAINER_DOMAIN}/api/users/admin/init" >/dev/null 2>&1 || true
  log_ok "Admin OK (ou já existia)"
else
  log_ok "Portainer já inicializado (ou status endpoint diferente)"
fi

# -------- 9. Status final / Dicas --------
step "Status dos serviços"
docker service ls | egrep 'traefik|portainer' || true

echo
echo "==============================================="
echo -e " ${GREEN}Instalação concluída${RESET}"
echo -e " Servidor (label): ${SERVER_NAME}"
echo -e " Rede overlay:     ${NETWORK_NAME}"
echo -e " Portainer:        https://${PORTAINER_DOMAIN}"
echo -e "   Usuário:        ${PORTAINER_USER}"
echo -e "   Senha:          (a que você informou)"
echo "==============================================="
echo
echo -e "${INFO} Se usa Cloudflare, mantenha ${B}nuvem cinza${RESET} até emitir. Para AAAA (IPv6), remova se o host não atende IPv6."
echo -e "${INFO} Diagnóstico rápido:"
echo "  docker service logs traefik_traefik -f --since 15m"
echo "  docker service logs portainer_portainer -f --since 15m"
echo "  docker run --rm -v volume_swarm_certificates:/etc/traefik/letsencrypt bash:5.2 bash -lc 'ls -l /etc/traefik/letsencrypt; stat -c \"%a %n\" /etc/traefik/letsencrypt/acme.json'"
echo "  ss -ltnp | egrep ':80|:443'"
echo "  dig +short A ${PORTAINER_DOMAIN}; dig +short AAAA ${PORTAINER_DOMAIN}"
