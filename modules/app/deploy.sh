#!/bin/bash
# =====================================================================
# /opt/yoon/deploy.sh : (re)lance les conteneurs de Yoon sur cette instance.
#
# Usage :
#   deploy.sh                 -> api et web, tag "latest"
#   deploy.sh all  <tag>      -> api et web au tag donné
#   deploy.sh api  <tag>      -> seulement l'API (le web est redémarré ensuite)
#   deploy.sh web  <tag>      -> seulement le frontend
#
# Appelé au premier démarrage (user data), puis par les workflows de
# déploiement via SSM Run Command. Les secrets sont relus dans SSM à chaque
# exécution : changer un paramètre puis redéployer suffit à l'appliquer.
# =====================================================================
set -euo pipefail

CIBLE="${1:-all}"
TAG="${2:-latest}"

# ENV, REGION, REGISTRY, API_REPO, WEB_REPO, INSTANCE_ROLE (écrits par le user data)
source /opt/yoon/instance.env

journal() { echo "[deploy $(date -u +%H:%M:%S)] $*"; }

param() {
  aws ssm get-parameter --region "$REGION" --name "/yoon/$ENV/$1" \
    --with-decryption --query Parameter.Value --output text
}

ecrire_env_api() {
  local demo cors
  demo="$(param demo_data)"
  # Une seule instance crée les données de démonstration.
  if [ "$INSTANCE_ROLE" != "primary" ]; then demo="false"; fi
  cors="$(param cors_allowed_origins)"

  umask 077
  {
    echo "SPRING_PROFILES_ACTIVE=prod"
    echo "DB_URL=$(param db_url)"
    echo "DB_USERNAME=$(param db_username)"
    echo "DB_PASSWORD=$(param db_password)"
    echo "JWT_SECRET=$(param jwt_secret)"
    echo "QR_SECRET=$(param qr_secret)"
    echo "DEMO_DATA=$demo"
    echo "JAVA_OPTS=-Xms128m -Xmx$(param java_max_heap) -Dfile.encoding=UTF-8"
    if [ "$cors" != "none" ]; then echo "CORS_ALLOWED_ORIGINS=$cors"; fi
  } > /opt/yoon/api.env
}

connexion_ecr() {
  aws ecr get-login-password --region "$REGION" \
    | docker login --username AWS --password-stdin "$REGISTRY" > /dev/null
}

attendre_api() {
  journal "attente de l'API (jusqu'à 4 min)"
  for _ in $(seq 1 48); do
    if docker exec api wget -qO- http://localhost:8093/actuator/health/readiness 2>/dev/null | grep -q UP; then
      journal "API prête"
      return 0
    fi
    sleep 5
  done
  journal "ERREUR : l'API n'est pas prête ; derniers journaux :"
  docker logs --tail 80 api || true
  return 1
}

lancer_api() {
  ecrire_env_api
  docker pull "$REGISTRY/$API_REPO:$TAG"
  docker rm -f api > /dev/null 2>&1 || true
  docker run -d --name api --network yoon --restart unless-stopped \
    --env-file /opt/yoon/api.env \
    --memory 640m \
    --log-opt max-size=10m --log-opt max-file=3 \
    "$REGISTRY/$API_REPO:$TAG" > /dev/null
  attendre_api
  echo "$TAG" > /opt/yoon/api.tag
}

lancer_web() {
  docker pull "$REGISTRY/$WEB_REPO:$TAG"
  docker rm -f web > /dev/null 2>&1 || true
  docker run -d --name web --network yoon --restart unless-stopped \
    -p 80:80 -e API_UPSTREAM=http://api:8093 \
    --memory 128m \
    --log-opt max-size=10m --log-opt max-file=3 \
    "$REGISTRY/$WEB_REPO:$TAG" > /dev/null
  echo "$TAG" > /opt/yoon/web.tag
}

journal "cible=$CIBLE tag=$TAG env=$ENV role=$INSTANCE_ROLE"
connexion_ecr
docker network create yoon > /dev/null 2>&1 || true

case "$CIBLE" in
  all)
    lancer_api
    lancer_web
    ;;
  api)
    lancer_api
    # nginx résout l'adresse de « api » au démarrage : on le redémarre
    # pour qu'il suive le nouveau conteneur.
    if docker ps --format '{{.Names}}' | grep -qx web; then docker restart web > /dev/null; fi
    ;;
  web)
    lancer_web
    ;;
  *)
    echo "Cible inconnue : $CIBLE (attendu : all, api ou web)" >&2
    exit 2
    ;;
esac

docker image prune -f > /dev/null
journal "terminé : api=$(cat /opt/yoon/api.tag 2>/dev/null || echo '-') web=$(cat /opt/yoon/web.tag 2>/dev/null || echo '-')"
