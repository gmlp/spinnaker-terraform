#!/bin/bash

#######################################################

#  This Script can be used to: 
#   - configure Spinnaker Halyard.

#######################################################


until hal --ready
do
    echo "Halyard deamon is not yet ready. Sleeping for a while..."
    sleep 15 
done

CONTEXT=$(kubectl config current-context)

hal config provider kubernetes enable
hal config provider kubernetes account add eks-cluster \
 --provider-version v2 \
 --context "$CONTEXT" 

hal config deploy edit \
 --type distributed \
 --account-name eks-cluster