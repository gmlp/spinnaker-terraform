#!/bin/bash 
#######################################################

#  This Script can be used to:
#   - Install and configure Spinnaker
#   - Expose Spinnaker through Ingress using
#      noip free domain
#   - depends on:
#       * Docker
#       * gmlpdou/halyard:stable image
#       * scripts/hal_config.sh
#       * scripts/s3_config.exp
#       * scripts/deploy.sh

#######################################################

readonly BUCKET=$1
readonly ACCESS_KEY_ID=$2
readonly SECRET_ACCESS_KEY=$3
readonly CONFIG_DIR="${PWD}/.config"
readonly SPINNAKER_HOME="/home/spinnaker"

export KUBECONFIG="${CONFIG_DIR}/kubeconfig"

docker run -d  \
    --name halyard --rm \
    -v ~/.hal:"$SPINNAKER_HOME/.hal" \
    gmlpdou/halyard:stable

docker exec halyard mkdir "${SPINNAKER_HOME}/.kube"
docker exec halyard mkdir "${SPINNAKER_HOME}/.aws"

# TODO: create a user for eks 
#       - use aws cli utility to pass eks credentials
#       - credentials are passed directly
#       *** credentials file must exist ****
docker cp .config/credentials "halyard:${SPINNAKER_HOME}/.aws"
docker cp "$KUBECONFIG" "halyard:${SPINNAKER_HOME}/.kube/config"

# Copy Scripts
docker cp scripts/hal_config.sh "halyard:${SPINNAKER_HOME}/hal_config.sh"
docker cp scripts/s3_config.exp "halyard:${SPINNAKER_HOME}/s3_config.exp"
docker cp scripts/deploy.sh "halyard:${SPINNAKER_HOME}/deploy.sh"

docker exec -u root halyard chown -R spinnaker:spinnaker "${SPINNAKER_HOME}"

docker exec halyard bash "${SPINNAKER_HOME}/hal_config.sh"

docker exec halyard chmod +x "${SPINNAKER_HOME}/s3_config.exp"
docker exec -t halyard ${SPINNAKER_HOME}/s3_config.exp "$BUCKET" "$ACCESS_KEY_ID" "$SECRET_ACCESS_KEY" 

#####################################################
# This uses noip free domain
# TODO: if domain is provided this should not be used
#####################################################

LB_HOST=$(kubectl -n ingress-nginx \
    get svc ingress-nginx \
    -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")

LB_IP="$(dig +short $LB_HOST \
    | tail -n 1)"

DECK_HOST="deck.${LB_IP}.nip.io"
GATE_HOST="gate.${LB_IP}.nip.io"
PROTOCOL="http"

docker exec halyard bash "${SPINNAKER_HOME}/deploy.sh" "${DECK_HOST}" "${GATE_HOST}" "${PROTOCOL}"

helm upgrade -i spinnaker-ingress \
 --namespace spinnaker \
 --set ingress.deck.host="${DECK_HOST}" \
 --set ingress.gate.host="${GATE_HOST}" \
 kubernetes/charts/spinnaker-ingress