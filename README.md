## Preparation
1. Create an `env.sh` file to store secret used for provisioning. Something like the following.
    ```bash
        touch env.sh
    ```
    ```bash
        echo "export CONFLUENT_CLOUD_API_KEY="<cloud-key>"\nexport CONFLUENT_CLOUD_API_SECRET="<cloud-secret>" > env.sh
    ```
1. Source the `env.sh` file once you've copied in the contents of your Cloud Key & Secret.
    ```bash
        source env.sh
    ```
1. Navigate to the `/terraform` directory and initialize Terraform. 
    ```bash
        cd terraform
    ```
    ```bash
        terraform init
    ```
1. Create and apply the Terraform configuration.
    ```bash
        terraform plan
    ```
    ```bash
        terraform apply -auto-approve
    ```    

## From Source

### Install from Source
1. Change to the correct directory before starting. 
    ```bash
        cd with-source
    ```
1. Download the Confluent Platform components. 
    ```bash
        curl -O http://packages.confluent.io/archive/7.3/confluent-7.3.0.tar.gz
    ```
1. Unpack the archive. 
    ```bash
        tar xzf confluent-7.3.0.tar.gz
    ```

### Start the worker
1. Start by installing a Connector from the Confluent Hub prior to starting the worker.
    ```bash
        sh confluent-7.3.0/bin/confluent-hub install debezium/debezium-connector-postgresql:1.9.7 --no-prompt --component-dir plugins/
    ```
    This will add the `debezium/debezium-connector-postgresql:1.9.7` components to our plugin path. You can swap the connector definition above with whatever you want from the Confluent Hub, but the set of examples in this repo were meant for Postgres. 
1. The Terraform configuration should have created a working Kafka Connect properties file. We can pass that to `connect-distributed` to bring our worker online. 
    ```bash
        confluent-7.3.0/bin/connect-distributed worker.properties
    ```
1. When the worker is online, you can list currently running connectors (which should be none) with the following request to the Connect cluster's REST API endpoint.
    ```bash
        curl -X GET localhost:8083/connectors
    ```
    It is expected that this will return an empty list (since we haven't configured any connectors yet), looking something like this: `[]%`.
1. Once Connect is running (or while it's starting up), start Control Center as well. When Control Center is online, you can navigate to <a>http://localhost:9021</a> to view the UI.
    ```bash
        confluent-7.3.0/bin/control-center-start control-center.properties
    ```
1. In order to create a connector, create an instance of Postgres as a container.
    ```bash
        docker compose up -d
    ```

## From Docker

### Launch Connect
1. The Terraform configuration should have created a `docker-compose.yaml` with your properties. We can use this right away to start Connect and Control Center locally. 
    ```bash
        docker compose up -d
    ```
1. Once Connect is running (mind the logs, compose will say the service is available before the startup process actually completes), list the connectors by making a call to the Connect cluster's REST API endpoint. 
    ```bash
        curl -X GET localhost:8083/connectors
    ```

## Connector lifecycle (create, update, delete)

> **Note:** *Since there are two approaches to the deployment, two config files were necessary and they vary slightly. Based on the deployment currently in use, switch between the `source` and `docker` prefix seen in the commands below.*

1. To create a new connector, you will either need to A, POST a new connector config to the Connect cluster REST API endpoint or B, create and configure a new instance of the connector in the Control Center UI. To start, test this with the REST API. Scripts with the requests have been provided in `/postgres/connectors`. 
    ```bash
        cd ../postgres/connectors
    ```
    ```bash
        sh create-connector.sh <source|docker>-postgres-cdc-config.json
    ```
    You should see something similar to the following as an output if the connector was created successfully.
    ```json
        {
            "name": "PostgresConnectorConnector",
            "config": {
                "name": "PostgresConnectorConnector",
                "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
                "tasks.max": "1",
                "database.server.name": "postgres",
                "database.hostname": "postgres",
                "database.port": "5432",
                "database.user": "postgres",
                "database.password": "c00l-p0stgr3s",
                "database.dbname": "postgres",
                "slot.name": "hellojeff",
                "table.include.list": "ecommerce.orders, ecommerce.products, ecommerce.customers, ecommerce.demographics",
                "topic.creation.groups": "ecommerce",
                "topic.creation.ecommerce.include": "postgres.ecommerse.*",
                "topic.creation.ecommerce.replication.factor": "3",
                "topic.creation.ecommerce.partitions": "6",
                "topic.creation.ecommerce.cleanup.policy": "delete",
                "topic.creation.default.replication.factor": "3",
                "topic.creation.default.partitions": "6"
            },
            "tasks": [],
            "type": "source"
        }
    ```
1. After the connector has been deployed, you can update it by placing a PUT request to the REST API endpoint with the connector's name in the path and a `config` object of key-value pairs as the request body, such as the following.

    > **Example:** `curl -X PUT --data "{ "tasks.max":"3" }" http://connect:8083/connectors/TheNameOfTheConnectorToUpdate/config` would set the value of `tasks.max` to 3 for the connector `TheNameOfTheConnectorToUpdate`.

    To update the connector you created above, make a change to either `source-postgres-cdc-config.json` or `docker-postgres-cdc-config.json` depending on what deployment you're using, for example, change the `tasks.max` to 3 like above. After saving the file, running the following script to update the connector.
    ```bash
        sh update-connector.sh <source|docker>-postgres-cdc-config.json
    ```


1. To delete a connector, you simply need to placing a DELETE request to the REST API endpoint with the connector's name in the path, such as the following.
    
    > **Example:** `curl -X DELETE http://connect:8083/connectors/TheNameOfTheConnectorToDelete` would delete the connector `TheNameOfTheConnectorToDelete`.

    To delete the connector you created above, use the provided script.
    ```bash
        sh delete-connector.sh <source|docker>-postgres-cdc-config.json
    ```

## Useful links

* https://docs.confluent.io/platform/current/installation/installing_cp/zip-tar.html 
* https://docs.confluent.io/platform/current/installation/docker/image-reference.html#docker-image-reference-for-cp 
* https://www.confluent.io/hub/ 
* https://docs.confluent.io/kafka-connectors/self-managed/kafka_connectors.html
* https://docs.confluent.io/platform/current/connect/references/allconfigs.html#distributed-worker-configuration
* https://docs.confluent.io/platform/current/control-center/installation/configuration.html