#!/bin/bash
# ---------------------------------------------------------------------
# Auto-instalador de Portainer + Traefik (Swarm)
# ---------------------------------------------------------------------
#  - Oculta grande parte dos outputs (para ficar mais limpo).
#  - Pede confirmação do IP detectado e dos dados de configuração.
#  - Mostra status final e, se falhar, permite refazer o processo.

################################
# Seções de Log e Funções Básicas
################################

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

# Executa comando silenciosamente,
# se falhar, exibe ERRO e aborta.
function run_cmd() {
  local cmd="$1"
  local msg="$2"
  log_info "$msg"
  eval "$cmd" &> /dev/null
  if [ $? -ne 0 ]; then
    log_error "Falha ao executar: $cmd"
    exit 1
  fi
  log_ok "$msg - concluído."
}

# Função para remover stacks, sair do Swarm etc. (caso algo dê errado e o usuário queira recomeçar)
function cleanup_and_retry() {
  echo "Removendo stacks e saindo do Swarm para recomeçar do zero..."
  docker stack rm portainer &>/dev/null
  docker stack rm traefik &>/dev/null
  sleep 5
  docker swarm leave --force &>/dev/null
  docker system prune -af &>/dev/null
  
  # Apaga arquivos temporários
  rm -f /tmp/stack-portainer.yml
  rm -f /tmp/stack-traefik.yml
  log_ok "Limpeza feita. Agora você pode executar o script novamente."
  exit 0
}

############################
# 1. Atualização do sistema
############################
run_cmd "sudo apt-get update -y && sudo apt-get upgrade -y" "Atualizando pacotes do sistema"

##################################
# 2. Verificando/Instalando deps
##################################

# sudo
if ! dpkg -l | grep -q sudo; then
  run_cmd "sudo apt-get install -y sudo" "Instalando sudo"
fi

# apt-utils
if ! dpkg -l | grep -q apt-utils; then
  run_cmd "sudo apt-get install -y apt-utils" "Instalando apt-utils"
fi

# python3
if ! command -v python3 &>/dev/null; then
  run_cmd "sudo apt-get install -y python3" "Instalando python3"
fi

# git
if ! command -v git &>/dev/null; then
  run_cmd "sudo apt-get install -y git" "Instalando git"
fi

# docker
if ! command -v docker &>/dev/null; then
  log_info "Instalando Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh &>/dev/null
  sh get-docker.sh &>/dev/null
  if ! command -v docker &>/dev/null; then
    log_error "Falha ao instalar Docker!"
    exit 1
  fi
  log_ok "Docker instalado."
else
  log_ok "Docker já instalado."
fi

###################################################
# 3. Inicializa Swarm se não estiver ativo
###################################################
SWARM_ACTIVE=$(docker info 2>/dev/null | grep "Swarm" | awk '{print $2}')
if [ "$SWARM_ACTIVE" != "active" ]; then
  log_info "Docker Swarm não está ativo. Tentando iniciar..."

  # Tenta detectar o primeiro IPv4 local
  DETECTED_IP=$(hostname -I | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)

  if [ -z "$DETECTED_IP" ]; then
    # Se não conseguiu detectar, inicia sem param
    log_info "Não foi possível detectar IP automaticamente. Iniciando Swarm sem --advertise-addr..."
    docker swarm init &>/dev/null || true
  else
    # Pergunta se o IP é o correto
    echo "Detectamos o IP: $DETECTED_IP"
    read -p "Este IP é o seu IPv4 público? (s/n): " CONF_IP
    if [[ "$CONF_IP" == "s" || "$CONF_IP" == "S" ]]; then
      docker swarm init --advertise-addr "$DETECTED_IP" &>/dev/null || true
    else
      read -p "Informe o IP público IPv4 correto: " USER_IP
      docker swarm init --advertise-addr "$USER_IP" &>/dev/null || true
    fi
  fi

  SWARM_ACTIVE_AGAIN=$(docker info 2>/dev/null | grep "Swarm" | awk '{print $2}')
  if [ "$SWARM_ACTIVE_AGAIN" != "active" ]; then
    log_error "Falha ao inicializar o Swarm. Verifique se há múltiplos IPs na mesma interface."
    exit 1
  else
    log_ok "Swarm inicializado com sucesso."
  fi
else
  log_ok "Swarm já está ativo."
fi

###################################################
# 4. Coleta de dados do usuário (com confirmação)
###################################################
while true; do
  echo -e "\n========================================="
  echo "Por favor, informe os dados para configuração:"
  read -p "Nome da rede interna (overlay): " NETWORK_NAME
  read -p "Nome do servidor (descrição/hostname): " SERVER_NAME
  read -p "E-mail para Let's Encrypt (Traefik): " EMAIL_LETSENCRYPT
  read -p "Domínio para Portainer (ex.: portainer.seudominio.com): " PORTAINER_DOMAIN

  echo -e "\nVocê informou:"
  echo " - Rede interna: $NETWORK_NAME"
  echo " - Nome do servidor: $SERVER_NAME"
  echo " - E-mail Let's Encrypt: $EMAIL_LETSENCRYPT"
  echo " - Domínio Portainer: https://$PORTAINER_DOMAIN"

  read -p "Está tudo correto? (s/n): " CONF_ALL
  if [[ "$CONF_ALL" == "s" || "$CONF_ALL" == "S" ]]; then
    break
  fi
  echo "Ok, vamos refazer as perguntas..."
done

###################################################
# 5. Criação de volumes e rede
###################################################
run_cmd "docker volume create portainer_data" "Criando volume portainer_data (se não existir)"
run_cmd "docker volume create volume_swarm_shared" "Criando volume volume_swarm_shared (se não existir)"
run_cmd "docker volume create volume_swarm_certificates" "Criando volume volume_swarm_certificates (se não existir)"

log_info "Criando rede overlay '$NETWORK_NAME' (se não existir)..."
docker network create --driver overlay --attachable "$NETWORK_NAME" &>/dev/null || true
log_ok "Rede '$NETWORK_NAME' verificada/criada."

###################################################
# 6. Gera docker-compose do Portainer
###################################################
log_info "Gerando stack do Portainer em /tmp/stack-portainer.yml..."
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
log_ok "Stack Portainer gerada."

###################################################
# 7. Gera docker-compose do Traefik
###################################################
log_info "Gerando stack do Traefik em /tmp/stack-traefik.yml..."
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
log_ok "Stack Traefik gerada."

########################################
# 8. Faz deploy de Portainer e Traefik
########################################
log_info "Fazendo deploy do stack Portainer..."
docker stack deploy -c /tmp/stack-portainer.yml portainer &>/dev/null

log_info "Fazendo deploy do stack Traefik..."
docker stack deploy -c /tmp/stack-traefik.yml traefik &>/dev/null

sleep 5
log_ok "Deploy enviado ao Docker Swarm. Verificando status..."

########################################
# 9. Verifica se os serviços subiram
########################################
# Aguardar alguns segundos e checar se ambos têm tarefas rodando
sleep 5
P_STATUS=$(docker stack ps portainer --format "{{.CurrentState}}" 2>/dev/null | grep "Running" | wc -l)
T_STATUS=$(docker stack ps traefik --format "{{.CurrentState}}" 2>/dev/null | grep "Running" | wc -l)

if [[ "$P_STATUS" -gt 0 && "$T_STATUS" -gt 0 ]]; then
  echo "------------------------------------------------------------"
  log_ok "Instalação Concluída com Sucesso!"
  echo -e "${INFO} - Rede interna: $NETWORK_NAME"
  echo -e "${INFO} - Nome do Servidor: $SERVER_NAME"
  echo -e "${INFO} - E-mail Let's Encrypt: $EMAIL_LETSENCRYPT"
  echo -e "${INFO} - Domínio do Portainer: https://${PORTAINER_DOMAIN}"
  echo "------------------------------------------------------------"
  echo "Para verificar detalhes: docker stack ps portainer e docker stack ps traefik"
  echo "------------------------------------------------------------"
else
  log_error "Parece que um ou mais serviços não estão em Running."
  echo "Quer tentar remover tudo e rodar a instalação novamente?"
  read -p "(s/n): " RETRY
  if [[ "$RETRY" == "s" || "$RETRY" == "S" ]]; then
    cleanup_and_retry
  else
    echo "Encerrando sem refazer a instalação."
    exit 1
  fi
fi
