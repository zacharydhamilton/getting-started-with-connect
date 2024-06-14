variable "cloud_provider" {
    type = string
    default = "AWS"
    validation {
        condition = contains(["AWS", "GCP", "AZURE"], var.cloud_provider)
        error_message = "Allowed values are [\"AWS\", \"GCP\", \"AZURE\"]"
    }
}
variable "cloud_region" {
    type = string
    default = "us-east-2"
}
variable "env_name" {
    type = string
    default = "getting-started-with-connect"
}
variable "cluster_name" {
    type = string
    default = "kafka"
}