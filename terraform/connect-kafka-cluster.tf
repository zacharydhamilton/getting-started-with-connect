terraform {
    required_providers {
        confluent = {
            source = "confluentinc/confluent"
            version = "1.13.0"
        }
        local = {
            source = "hashicorp/local"
            version = "2.2.3"
        }
        template = {
            source = "hashicorp/template"
            version = "2.2.0"
        }
    }
}

provider "confluent" {
    # Set through env vars as:
    # CONFLUENT_CLOUD_API_KEY="CLOUD-KEY"
    # CONFLUENT_CLOUD_API_SECRET="CLOUD-SECRET"
}
provider "local" {
    # For writing configs to a file
}

resource "random_id" "id" {
    byte_length = 4
}

resource "confluent_environment" "default_env" {
    display_name = "${local.env_name}-${random_id.id.hex}"
    lifecycle {
        prevent_destroy = false
    }
}

resource "confluent_kafka_cluster" "default_cluster" {
    display_name = "${local.cluster_name}"
    availability = "SINGLE_ZONE"
    cloud = "AWS"
    region = "us-east-2"
    basic {}
    environment {
        id = confluent_environment.default_env.id
    }
    lifecycle {
        prevent_destroy = false
    }
}

resource "confluent_service_account" "app_manager" {
    display_name = "app-manager-${random_id.id.hex}"
    description = "${local.description}"
}

resource "confluent_service_account" "clients" {
    display_name = "client-${random_id.id.hex}"
    description = "${local.description}"
}

resource "confluent_role_binding" "app_manager_environment_admin" {
    principal = "User:${confluent_service_account.app_manager.id}"
    role_name = "EnvironmentAdmin"
    crn_pattern = confluent_environment.default_env.resource_name
}

resource "confluent_role_binding" "clients_cluster_admin" {
    principal = "User:${confluent_service_account.clients.id}"
    role_name = "CloudClusterAdmin"
    crn_pattern = confluent_kafka_cluster.default_cluster.rbac_crn
}

resource "confluent_api_key" "app_manager_default_cluster_key" {
    display_name = "app-manager-${local.cluster_name}-key-${random_id.id.hex}"
    description = "${local.description}"
    owner {
        id = confluent_service_account.app_manager.id
        api_version = confluent_service_account.app_manager.api_version
        kind = confluent_service_account.app_manager.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.default_cluster.id
        api_version = confluent_kafka_cluster.default_cluster.api_version
        kind = confluent_kafka_cluster.default_cluster.kind
        environment {
            id = confluent_environment.default_env.id
        }
    }
    depends_on = [
        confluent_role_binding.app_manager_environment_admin
    ]
}

resource "confluent_api_key" "clients_default_cluster_key" {
    display_name = "clients-${local.cluster_name}-key-${random_id.id.hex}"
    description = "${local.description}"
    owner {
        id = confluent_service_account.clients.id
        api_version = confluent_service_account.clients.api_version
        kind = confluent_service_account.clients.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.default_cluster.id
        api_version = confluent_kafka_cluster.default_cluster.api_version
        kind = confluent_kafka_cluster.default_cluster.kind
        environment {
            id = confluent_environment.default_env.id
        }
    }
    depends_on = [
        confluent_role_binding.clients_cluster_admin
    ]
}
# ------------------------------------------------------------
# The following will interpolate the correct values into 
# properties files
# ------------------------------------------------------------
data "template_file" "with_source_worker_properties_template" {
    template = "${file("../with-source/worker.tmpl")}"
    vars = {
        bootstrap_server = substr(confluent_kafka_cluster.default_cluster.bootstrap_endpoint,11,-1)
        kafka_cluster_key = confluent_api_key.clients_default_cluster_key.id
        kafka_cluster_secret = confluent_api_key.clients_default_cluster_key.secret
        fully_qualified_path = abspath(dirname("../"))
    }
}
resource "local_file" "with_source_worker_properties" {
    filename = "../with-source/worker.properties"
    content = data.template_file.with_source_worker_properties_template.rendered
}
data "template_file" "with_docker_docker_compose_yaml_template" {
    template = "${file("../with-docker/docker-compose.tmpl")}"
    vars = {
        bootstrap_server = substr(confluent_kafka_cluster.default_cluster.bootstrap_endpoint,11,-1)
        kafka_cluster_key = confluent_api_key.clients_default_cluster_key.id
        kafka_cluster_secret = confluent_api_key.clients_default_cluster_key.secret
    }
}
resource "local_file" "with_docker_docker_compose_yaml" {
    filename = "../with-docker/docker-compose.yaml"
    content = data.template_file.with_docker_docker_compose_yaml_template.rendered
}
data "template_file" "with_source_control_center_properties_template" {
    template = "${file("../with-source/control-center.tmpl")}"
    vars = {
        bootstrap_server = substr(confluent_kafka_cluster.default_cluster.bootstrap_endpoint,11,-1)
        kafka_cluster_key = confluent_api_key.clients_default_cluster_key.id
        kafka_cluster_secret = confluent_api_key.clients_default_cluster_key.secret
        fully_qualified_path = abspath(dirname("../"))
    }
}
resource "local_file" "with_source_control_center_properties" {
    filename = "../with-source/control-center.properties"
    content = data.template_file.with_source_control_center_properties_template.rendered
}
data "template_file" "postgres_connector_docker_jdbc_sink_config_json_template" {
    template = "${file("../postgres/connector/docker-jdbc-sink-config.tmpl")}"
    vars = {
        kafka_cluster_key = confluent_api_key.clients_default_cluster_key.id
        kafka_cluster_secret = confluent_api_key.clients_default_cluster_key.secret
    }
}
resource "local_file" "postgres_connector_docker_jdbc_sink_config_json" {
    filename = "../postgres/connector/docker-jdbc-sink-config.json"
    content = data.template_file.postgres_connector_docker_jdbc_sink_config_json_template.rendered
}