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
1. The Terraform configuration should have created a working Kafka Connect properties file. We can pass that to `connect-distributed` to bring our worker online. 
    ```bash
        confluent-7.3.0/bin/connect-distributed worker.properties
    ```
    * If you want to specify a Connector from the Confluent Hub to install prior to starting the worker, do so like the following:
        ```bash
            sh confluent-7.3.0/bin/confluent-hub install debezium/debezium-connector-postgresql:1.9.7 --no-prompt --component-dir plugins/
        ```
        This will add the `debezium/debezium-connector-postgresql:1.9.7` components to our plugin path. You can swap the connector definition above with whatever you want from the Confluent Hub.
1. When the worker is online, you can list currently running connectors (which should be none) with the following request to the Connect cluster's REST API endpoint.
    ```bash
        curl -X GET localhost:8083/connectors
    ```
    It is expected that this will return an empty list (since we haven't configured any connectors yet), looking something like this: `[]%`.

## From Docker

### Launch Connect
1. The Terraform configuration should have created a `docker-compose.yaml` with your properties. We can use this right away to start Connect locally. 
    ```bash
        docker compose up -d
    ```
1. Once Connect is running (mind the logs, compose will say the service is available before the startup process actually completes), list the connectors by making a call to the Connect cluster's REST API endpoint. 
    ```bash
        curl -X GET localhost:8083/connectors
    ```