#!/bin/bash
#######################################################

#  This Script can be used to: 
#   - Install Ingress
#   - Install Tiller

#######################################################

readonly KUBECONFIG=$1
readonly MODULE_PATH=$2

until kubectl get nodes
do
    echo "Cluster is not yet ready. Sleeping for a while..."
    sleep 30
done

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
