#!/bin/bash

if [[ -z $1 ]]; then
    echo "FAILED: Please provide a config file name as an argument."
    exit 1
fi

HEADER="Content-Type: application/json"
DATA=$( cat $1 )

curl -X POST -H "${HEADER}" --data "${DATA}" http://localhost:8083/connectors | jq
