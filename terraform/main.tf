terraform {
    required_providers {
        confluent = {
            source = "confluentinc/confluent"
            version = "1.76.0"
        }
        local = {
            source = "hashicorp/local"
            version = "2.5.1"
        }
    }
}

provider "confluent" {
    # Set through env vars as:
    # CONFLUENT_CLOUD_API_KEY="CLOUD-KEY"
    # CONFLUENT_CLOUD_API_SECRET="CLOUD-SECRET"
}
resource "random_id" "id" {
    byte_length = 3
}

resource "confluent_environment" "env" {
    display_name = "${var.env_name}-${random_id.id.hex}"
    lifecycle {
        prevent_destroy = false
    }
}
data "confluent_schema_registry_region" "sr" {
    cloud = var.cloud_provider
    region = var.cloud_region
    package = "ADVANCED"
}
resource "confluent_schema_registry_cluster" "sr" {
    package = data.confluent_schema_registry_region.sr.package
    environment {
        id = confluent_environment.env.id
    }
    region {
        id = data.confluent_schema_registry_region.sr.id
    }
}
resource "confluent_kafka_cluster" "kafka" {
    display_name = "${var.cluster_name}-${random_id.id.hex}"
    availability = "SINGLE_ZONE"
    cloud = var.cloud_provider
    region = var.cloud_region
    basic {}
    environment {
        id = confluent_environment.env.id
    }
    lifecycle {
        prevent_destroy = false
    }
}

resource "confluent_service_account" "app_manager" {
    display_name = "app-manager-${random_id.id.hex}"
    description = "App Manager for 'Getting Started with Kafka Connect'"
}

resource "confluent_service_account" "clients" {
    display_name = "client-${random_id.id.hex}"
    description = "Service Account for 'Getting Started with Kafka Connect' clients and connectors"
}

resource "confluent_role_binding" "app_manager_environment_admin" {
    principal = "User:${confluent_service_account.app_manager.id}"
    role_name = "EnvironmentAdmin"
    crn_pattern = confluent_environment.env.resource_name
}

resource "confluent_role_binding" "clients_sr_resource_owner" {
    principal = "User:${confluent_service_account.clients.id}"
    role_name = "ResourceOwner"
    crn_pattern = format("%s/%s", confluent_schema_registry_cluster.sr.resource_name, "subject=*")
}

resource "confluent_role_binding" "clients_cluster_admin" {
    principal = "User:${confluent_service_account.clients.id}"
    role_name = "CloudClusterAdmin"
    crn_pattern = confluent_kafka_cluster.kafka.rbac_crn
}

resource "confluent_api_key" "app_manager_kafka_cluster_key" {
    display_name = "app-manager-${confluent_kafka_cluster.kafka.display_name}-key"
    description = "API Keys for App Manager on '${confluent_kafka_cluster.kafka.display_name}'"
    owner {
        id = confluent_service_account.app_manager.id
        api_version = confluent_service_account.app_manager.api_version
        kind = confluent_service_account.app_manager.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.kafka.id
        api_version = confluent_kafka_cluster.kafka.api_version
        kind = confluent_kafka_cluster.kafka.kind
        environment {
            id = confluent_environment.env.id
        }
    }
    depends_on = [
        confluent_role_binding.app_manager_environment_admin
    ]
}

resource "confluent_api_key" "clients_kafka_cluster_key" {
    display_name = "clients-${confluent_kafka_cluster.kafka.display_name}-key"
    description = "API Keys for Clients and Connectors on '${confluent_kafka_cluster.kafka.display_name}'"
    owner {
        id = confluent_service_account.clients.id
        api_version = confluent_service_account.clients.api_version
        kind = confluent_service_account.clients.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.kafka.id
        api_version = confluent_kafka_cluster.kafka.api_version
        kind = confluent_kafka_cluster.kafka.kind
        environment {
            id = confluent_environment.env.id
        }
    }
    depends_on = [
        confluent_role_binding.clients_cluster_admin
    ]
}

resource "confluent_api_key" "app_manager_sr_cluster_key" {
    display_name = "app-manager-${confluent_schema_registry_cluster.sr.id}-key"
    description = "API Keys for App Manager on '${confluent_schema_registry_cluster.sr.display_name}'"
    owner {
        id = confluent_service_account.app_manager.id
        api_version = confluent_service_account.app_manager.api_version
        kind = confluent_service_account.app_manager.kind
    }
    managed_resource {
        id = confluent_schema_registry_cluster.sr.id
        api_version = confluent_schema_registry_cluster.sr.api_version
        kind = confluent_schema_registry_cluster.sr.kind
        environment {
            id = confluent_environment.env.id
        }
    }
    depends_on = [
        confluent_role_binding.app_manager_environment_admin
    ]
}

resource "confluent_api_key" "clients_sr_cluster_key" {
    display_name = "clients-${confluent_schema_registry_cluster.sr.id}-key"
    description = "API Keys for Clients and Connectors on '${confluent_schema_registry_cluster.sr.display_name}'"
    owner {
        id = confluent_service_account.clients.id
        api_version = confluent_service_account.clients.api_version
        kind = confluent_service_account.clients.kind
    }
    managed_resource {
        id = confluent_schema_registry_cluster.sr.id
        api_version = confluent_schema_registry_cluster.sr.api_version
        kind = confluent_schema_registry_cluster.sr.kind
        environment {
            id = confluent_environment.env.id
        }
    }
    depends_on = [
        confluent_role_binding.clients_sr_resource_owner
    ]
}

# ------------------------------------------------------------
# The following will interpolate the correct values into 
# properties files
# ------------------------------------------------------------
resource "local_file" "with_source_worker_properties" {
    filename = "../with-source/worker.properties"
    content = templatefile("../with-source/worker.tmpl", {
        bootstrap_server = substr(confluent_kafka_cluster.kafka.bootstrap_endpoint,11,-1)
        kafka_cluster_key = confluent_api_key.clients_kafka_cluster_key.id
        kafka_cluster_secret = confluent_api_key.clients_kafka_cluster_key.secret
        schema_registry_cluster_key = confluent_api_key.clients_sr_cluster_key.id
        schema_registry_cluster_secret = confluent_api_key.clients_sr_cluster_key.secret
        schema_registry_cluster_endpoint = confluent_schema_registry_cluster.sr.rest_endpoint
        fully_qualified_path = abspath(dirname("../"))
    })
}
resource "local_file" "with_docker_docker_compose_yaml" {
    filename = "../with-docker/docker-compose.yaml"
    content = templatefile("../with-docker/docker-compose.tmpl", {
        bootstrap_server = substr(confluent_kafka_cluster.kafka.bootstrap_endpoint,11,-1)
        kafka_cluster_key = confluent_api_key.clients_kafka_cluster_key.id
        kafka_cluster_secret = confluent_api_key.clients_kafka_cluster_key.secret
        schema_registry_cluster_key = confluent_api_key.clients_sr_cluster_key.id
        schema_registry_cluster_secret = confluent_api_key.clients_sr_cluster_key.secret
        schema_registry_cluster_endpoint = confluent_schema_registry_cluster.sr.rest_endpoint
    })
}
resource "local_file" "with_source_control_center_properties" {
    filename = "../with-source/control-center.properties"
    content = templatefile("../with-source/control-center.tmpl", {
        bootstrap_server = substr(confluent_kafka_cluster.kafka.bootstrap_endpoint,11,-1)
        kafka_cluster_key = confluent_api_key.clients_kafka_cluster_key.id
        kafka_cluster_secret = confluent_api_key.clients_kafka_cluster_key.secret
        fully_qualified_path = abspath(dirname("../"))
    })
}
resource "local_file" "postgres_connector_docker_jdbc_sink_config_json" {
    filename = "../postgres/connectors/docker-jdbc-sink-config.json"
    content = templatefile("../postgres/connectors/docker-jdbc-sink-config.tmpl", {
        kafka_cluster_key = confluent_api_key.clients_kafka_cluster_key.id
        kafka_cluster_secret = confluent_api_key.clients_kafka_cluster_key.secret
    })
}
resource "local_file" "postgres_connector_source_jdbc_sink_config_json" {
    filename = "../postgres/connectors/source-jdbc-sink-config.json"
    content = templatefile("../postgres/connectors/source-jdbc-sink-config.tmpl", {
        kafka_cluster_key = confluent_api_key.clients_kafka_cluster_key.id
        kafka_cluster_secret = confluent_api_key.clients_kafka_cluster_key.secret
    })
}