#!/bin/bash
#
# © Copyright IBM Corp. 2025
#

set -e

# Check if the correct number of arguments are provided
if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
    echo "Usage: $0 <gateway-group> <gateway-id> <cluster-dns> [namespace]"
    exit 1
fi

GATEWAY_GROUP=$1
GATEWAY_ID=$2
CLUSTER_DNS=$3
NAMESPACE=""

# Check if a namespace argument is provided
if [ "$#" -eq 4 ]; then
    NAMESPACE=$4
fi

YAML_FILE="create-gateway-certificate.yaml"

# Read the YAML content into a variable
YAML_CONTENT=$(cat $YAML_FILE)

# Replace the placeholders in the YAML content
YAML_CONTENT=$(echo "$YAML_CONTENT" | sed "s/<gateway-group>/$GATEWAY_GROUP/g")
YAML_CONTENT=$(echo "$YAML_CONTENT" | sed "s/<gateway-id>/$GATEWAY_ID/g")
YAML_CONTENT=$(echo "$YAML_CONTENT" | sed "s/<cluster-dns>/$CLUSTER_DNS/g")

# Apply the customized YAML using kubectl
if [ -n "$NAMESPACE" ]; then
    kubectl apply -n $NAMESPACE -f - <<EOF
$YAML_CONTENT
EOF
else
    kubectl apply -f - <<EOF
$YAML_CONTENT
EOF
fi

echo "Customized YAML for certificate applied successfully."
