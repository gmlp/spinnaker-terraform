#!/bin/bash
######################################
#
#      This Script aims to: 
#       - Initialize EKS cluster.
#       - Install Ingress
#       - Install Tiller
#       - Create Spinnaker SA
#
######################################

KUBE_CONFIG=$1
AWS_AUTH_CM=$2
CONFIG_DIR="${PWD}/.config"

mkdir -p "${CONFIG_DIR}"

export KUBECONFIG="${CONFIG_DIR}/kubeconfig"
echo "${KUBE_CONFIG}" > "${KUBECONFIG}"
echo "${AWS_AUTH_CM}" > "${CONFIG_DIR}/aws_auth.yml"

until kubectl get nodes
do
    echo "Cluster is not yet ready. Sleeping for a while..."
    sleep 30
done

kubectl apply -f "${CONFIG_DIR}/aws_auth.yml" --record
rm "${CONFIG_DIR}/aws_auth.yaml" 

###################
# INSTALL INGRESS
###################

kubectl apply \
    -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/mandatory.yaml

kubectl apply \
    -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/provider/aws/service-l4.yaml

kubectl apply \
    -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/provider/aws/patch-configmap-l4.yaml

##################
# Install Tiller
##################

kubectl create \
    -f kubernetes/tiller-rbac.yml \
    --record --save-config

helm init --service-account tiller

kubectl -n kube-system \
    rollout status deploy tiller-deploy

##################
# Spinnaker SA
##################

CONTEXT=$(kubectl config current-context)

# This service account uses the ClusterAdmin role -- this is not necessary,
# more restrictive roles can by applied.
kubectl apply --context "${CONTEXT}" \
    -f https://spinnaker.io/downloads/kubernetes/service-account.yml


SECRET_NAME=$(kubectl get serviceaccount spinnaker-service-account \
       --context "${CONTEXT}" \
       -n spinnaker \
       -o jsonpath='{.secrets[0].name}')

TOKEN=$(kubectl get secret --context "$CONTEXT" \
    "${SECRET_NAME}" \
   -n spinnaker \
   -o jsonpath='{.data.token}' | base64 --decode)

kubectl config set-credentials "${CONTEXT}-token-user" --token "${TOKEN}"

kubectl config set-context "${CONTEXT}" --user "${CONTEXT}-token-user"
