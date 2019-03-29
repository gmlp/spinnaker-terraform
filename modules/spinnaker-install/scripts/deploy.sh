#!/bin/bash

#######################################################

#  This Script can be used to: 
#   - configure Spinnaker external storage.
#   - set Spinnaker endpoints.
#   - Deploy Spinnaker.

#######################################################

readonly DECK_HOST="$1"
readonly GATE_HOST="$2"
readonly PROTOCOL="$3" 

hal config storage edit --type s3

#To set a version
hal config version edit --version 1.11.6

# This is to update endpoints: solves cors issues
hal config security ui edit \
 --override-base-url "${PROTOCOL}://${DECK_HOST}"
 
hal config security api edit \
 --override-base-url "${PROTOCOL}://${GATE_HOST}" 

hal deploy apply