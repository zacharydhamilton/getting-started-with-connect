<div align="center" padding=25px>
    <img src="images/confluent.png" width=50% height=50%>
</div>

# <div align="center">Getting Started with Self-managed Kafka Connect</div>

## Background 
In a Kafka ecosystem, there are a variety of ways to get data from external systems and write it to Kafka, or take data from Kafka and write it to external systems. Possibly the most well-supported and popular of these solutions is Kafka Connect. Providing security, high-availability, resilience, and extensibility out-of-the-box, Kafka Connect works with almost any technology and in a way that is expected from the modern organization. 

The goal of this walk-through is to bring you up to speed with deploying Kafka Connect on your own in a few different ways. After going through these examples, you should have a simple working example of Kafka Connect in action.

### Prerequisites 

This walk-through requires a few prerequisites listed bellow. It's worth mentioning as well that this walk tested only on a Mac, and not all of the commands listed may work on Windows.

- [Confluent Cloud Account](https://docs.confluent.io/cloud/current/get-started/free-trial.html#free-trial-for-ccloud)
- [Confluent Cloud "Cloud API Key" and secret](https://docs.confluent.io/cloud/current/access-management/authenticate/api-keys/api-keys.html#cloud-cloud-api-keys)
- Docker
- Terraform
- Jq

## Preparation

To begin, prepare your environment with some necessary things, namely an "env" file to store your secrets 🤫. This "env" file and the resource built by Terraform will be necessary for all the other steps and part of the walk-through. 

1. Create an `env.sh` file to store secrets used for provisioning. Something like the following.
    ```bash
        touch env.sh
    ```
1. With an existing file named `env.sh`, add your Confluent Cloud "Cloud API Key" and secret into the following, and execute the command. 
    ```bash
        echo "export CONFLUENT_CLOUD_API_KEY="<cloud-key>"\nexport CONFLUENT_CLOUD_API_SECRET="<cloud-secret>" > env.sh
    ```
1. Source the `env.sh` file once you've added in the contents of your Cloud Key & Secret.
    ```bash
        source env.sh
    ```
1. Navigate to the `/terraform` directory. 
    ```bash
        cd terraform
    ```
1. Initialize Terraform.
    ```bash
        terraform init
    ```
1. Plan and apply the Terraform configuration.
    ```bash
        terraform plan
    ```
    ```bash
        terraform apply -auto-approve
    ```

At this point (everything going as planned 🤞), you should have everything you need to get started with either deploying Kafka Connect from source or deploying Kafka Connect using Docker. If you want to deploy Kafka Connect from source, click [here](#from-source) for those directions. If you want to deploy Kafka Connect using Docker, click [here](#from-docker) for those directions. If you want to do both, just scroll down. 


## From Source

### Download and unpack the software
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

### Start a Kafka Connect worker
1. The Connect Worker will require connector plugins in order to deploy instances of non-default connectors. Begin by creating a directory to download some connector plugins into. 
    ```bash
        mkdir plugins
    ```

1. Once your have a directory for connector plugins, use the `confluent-hub` executable to download the Postgres CDC Source and JDBC Source & Sink connector plugins.
    ```bash
        sh confluent-7.3.0/bin/confluent-hub install debezium/debezium-connector-postgresql:1.9.7 --no-prompt --component-dir plugins/
    ```
    ```bash
        sh confluent-7.3.0/bin/confluent-hub install confluentinc/kafka-connect-jdbc:10.6.0 --no-prompt --component-dir plugins/
    ```

1. The Terraform configuration should have created a working Kafka Connect properties file. You can pass that to `connect-distributed` to bring a worker online. 
    ```bash
        confluent-7.3.0/bin/connect-distributed worker.properties
    ```

1. When the worker is online, you can list currently running connectors (which should be none) with the following request to the Connect cluster's REST API endpoint.
    ```bash
        curl -X GET localhost:8083/connectors
    ```
    It is expected that this will return an empty list (since we haven't configured any connectors yet), looking something like this: `[]%`.

### Start an instance of Control Center
1. Once Connect is running (or while it's starting up), prepared to start Control Center by creating a data directory for it. 
    ```bash
        mkdir c3-data
    ```
1. Once you have a data directory, use the `control-center-start' executable and pass it the Terraform created properties file to bring it online. 
    ```bash
        confluent-7.3.0/bin/control-center-start control-center.properties
    ```
    When Control Center is online, you can navigate to <a>http://localhost:9021</a> to view the UI.

### Create your first connector

1. In order for the connector to do anything, start by launch two instances of Postgres you can read/write data to and from.
    ```bash
        docker compose up -d
    ```

1. Once the two instances of Postgres have been created, use the provided connector config files in order to create an instance of a Postgres CDC Source Connector.
    ```bash
        sh ../postgres/connectors/create-connector.sh source-postgres-cdc-config.json
    ```
    You should see something similar to the following as an output if the connector was created successfully.
    ```json
        {
            "name": "SourcePostgresConnectorCDCSource",
            "config": {
                "name": "SourcePostgresConnectorCDCSource",
                "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
                "tasks.max": "1",
                "database.server.name": "postgres",
                "database.hostname": "localhost",
                "database.port": "5432",
                "database.user": "postgres",
                "database.password": "c00l-p0stgr3s",
                "database.dbname": "postgres",
                "slot.name": "debeezy",
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
    Navigate to the Confluent Cloud UI and look for four topics named something like `postgres.ecommerce.<orders|products|customers|demographics>`. 

1. Once you've created the Postgres CDC Source Connector and see data in topics, you can now sink it back to another database. Use the following to now create a JDBC Sink Connector.
    ```bash
        sh ../postgres/connectors/create-connector.sh source-jdbc-sink-config.json
    ```
    Like the first connector, if successful you should see a JSON output in your terminal. 

### Cleanup the connectors, databases, cluster

1. When you're content with the connectors you've created, it's time to delete them. 
    ```bash
        sh ../postgres/connectors/delete-connector.sh source-postgres-cdc-config.json
    ```
    ```bash
        sh ../postgres/connectors/delete-connector.sh source-jdbc-sink-config.json
    ```

1. Shutdown the database instances.
    ```bash
        docker compose down
    ```

1. Control+C to interrupt the runtime of the Worker as well as Control Center. 

1. If you're going to follow the walk-through with Docker as well, skip this step! Otherwise, teardown your cloud environment and cluster with Terraform.
    ```bash
        cd ../terraform
    ```
    ```bash
        terraform destroy
    ```

## From Docker

### Launch Connect, Control Center, and Postgres
1. The Terraform configuration should have created a `docker-compose.yaml` with your properties. We can use this right away to start Connect and Control Center locally. 
    ```bash
        docker compose up -d
    ```

1. Once Connect is running (mind the logs, compose will say the service is available before the startup process actually completes), list the connectors by making a call to the Connect cluster's REST API endpoint. 
    ```bash
        curl -X GET localhost:8083/connectors
    ```

1. Additionally, when Control Center is online, you can view the Control Center UI by following this link: <a>http://localhost:9021</a>.

### Create your first connector

1. Two instances of Postgres should have been created with the Docker compose config. Use the provided connector config files in order to create an instance of a Postgres CDC Source Connector.
    ```bash
        sh ../postgres/connectors/create-connector.sh docker-postgres-cdc-config.json
    ```
    You should see something similar to the following as an output if the connector was created successfully.
    ```json
        {
            "name": "DockerPostgresConnectorCDCSource",
            "config": {
                "name": "DockerPostgresConnectorCDCSource",
                "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
                "tasks.max": "1",
                "database.server.name": "postgres",
                "database.hostname": "ecommerce-db",
                "database.port": "5432",
                "database.user": "postgres",
                "database.password": "c00l-p0stgr3s",
                "database.dbname": "postgres",
                "slot.name": "debeezy",
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
    Navigate to the Confluent Cloud UI and look for four topics named something like `postgres.ecommerce.<orders|products|customers|demographics>`. 

1. Once you've created the Postgres CDC Source Connector and see data in topics, you can now sink it back to another database. Use the following to now create a JDBC Sink Connector.
    ```bash
        sh ../postgres/connectors/create-connector.sh docker-jdbc-sink-config.json
    ```
    Like the first connector, if successful you should see a JSON output in your terminal. 

### Cleanup the connectors, databases, cluster

1. When you're content with the connectors you've created, it's time to delete them. 
    ```bash
        sh ../postgres/connectors/delete-connector.sh docker-postgres-cdc-config.json
    ```
    ```bash
        sh ../postgres/connectors/delete-connector.sh docker-jdbc-sink-config.json
    ```

1. Shutdown the worker, Control Center, and the Postgres instances.
    ```bash
        docker compose down
    ```

1. If you're going to follow the walk-through with Source as well, skip this step! Otherwise, teardown your cloud environment and cluster with Terraform.
    ```bash
        cd ../terraform
    ```
    ```bash
        terraform destroy
    ```

## Useful links

* https://docs.confluent.io/platform/current/installation/installing_cp/zip-tar.html 
* https://docs.confluent.io/platform/current/installation/docker/image-reference.html#docker-image-reference-for-cp 
* https://www.confluent.io/hub/ 
* https://docs.confluent.io/kafka-connectors/self-managed/kafka_connectors.html
* https://docs.confluent.io/platform/current/connect/references/allconfigs.html#distributed-worker-configuration
* https://docs.confluent.io/platform/current/control-center/installation/configuration.html