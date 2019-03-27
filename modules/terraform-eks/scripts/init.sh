#!/bin/bash
#######################################################

#  This Script can be used to: 
#   - Initialize EKS cluster.
#   - Install Ingress
#   - Install Tiller

#######################################################

readonly KUBE_CONFIG=$1
readonly AWS_AUTH_CM=$2
readonly MODULE_PATH=$3
readonly CONFIG_DIR="${PWD}/.config"

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
    -f "${MODULE_PATH}/kubernetes/tiller-rbac.yml" \
    --record --save-config

helm init --service-account tiller

kubectl -n kube-system \
    rollout status deploy tiller-deploy
