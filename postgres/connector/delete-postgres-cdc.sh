#!/bin/bash

if [[ -z $1 ]]; then
    echo "FAILED: Please provide a config file name as an argument."
    exit 1
fi

HEADER="Content-Type: application/json"
CONNECTOR_NAME=$( cat $1 | jq -r .name )

curl -X DELETE -H "${HEADER}" --data "${DATA}" http://localhost:8083/connectors/${CONNECTOR_NAME} | jq