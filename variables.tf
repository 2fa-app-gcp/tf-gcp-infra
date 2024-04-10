variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "credentials_file" {
  description = "Path to the Google Cloud credentials file"
}

variable "project_id" {
  description = "Google Cloud Project ID"
  default     = "network-cloud-002277864"
}

variable "region" {
  description = "Google Cloud region"
}

variable "vpc_name" {
  description = "Name of the VPC"
  default     = "my-vpc"
}

variable "routing_mode" {
  description = "Routing mode for the VPC"
  default     = "REGIONAL"
}

variable "webapp_subnet_cidr" {
  description = "CIDR range for the webapp subnetwork"
  default     = "100.1.1.0/24"
}

variable "db_subnet_cidr" {
  description = "CIDR range for the db subnetwork"
  default     = "100.1.2.0/24"
}

variable "default_route_dest_range" {
  description = "Destination range for the default route"
  default     = "0.0.0.0/0"
}

variable "machine_type" {
  description = "Machine type for the instance"
  default     = "e2-medium"
}

variable "zone" {
  description = "Zone for the instance"
  default     = "us-east1-b"
}

variable "image" {
  description = "Image for the instance"
  default     = "projects/network-cloud-002277864/global/images/web-app-20240221182725"
}

variable "size" {
  description = "Size for the instance's boot disk"
  default     = "100"
}

variable "type" {
  description = "Type for the instance's boot disk"
  default     = "pd-balanced"
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled for the database instance"
  type        = bool
  default     = false
}

variable "disk_type" {
  description = "The type of disk for the database instance"
  type        = string
  default     = "pd-ssd"
}

variable "disk_size" {
  description = "The size of the disk for the database instance"
  type        = number
  default     = 100
}

variable "availability_type" {
  description = "The availability type of the database instance"
  type        = string
  default     = "REGIONAL"
}

variable "tier" {
  description = "The machine type for the database instance"
  type        = string
  default     = "db-f1-micro"
}

variable "database_name" {
  description = "database name"
  type        = string
  default     = "webapp"
}

variable "domain_name" {
  description = "The domain name to be used for the DNS record"
}

variable "managed_zone" {
  description = "The name of the managed zone in Google Cloud DNS"
}

variable "account_id" {
  description = "account id for logging"
}

variable "topic" {
  description = "topic name"
}

variable "function_name" {
  description = "function name"
}

variable "bucket_name" {
  description = "bucket name"
}

variable "file_name" {
  description = "file name"
}

variable "serverless_connector_ip_range" {
  description = "ip cidr range for serverless vpc connection"
}

variable "apikey" {
  description = "api key"
}

variable "domain" {
  description = "domain name"
}

variable "binding_account" {
  description = "binding account"
}

variable "vm_account" {
  description = "vm account"
}

variable "minreplica" {
  description = "minimum replicas"
}

variable "maxreplica" {
  description = "maximum replicas"
}

variable "port" {
  description = "port number"
}

variable "cpu_utilization" {
  description = "cpu utilization"
}

variable "cooldown_period" {
  description = "cooldown_period"
}

variable "check_interval_sec" {
  description = "check_interval_sec"
}

variable "timeout_sec" {
  description = "timeout_sec"
}

variable "health_threshold" {
  description = "threshold for health check"
}

variable "key_ring_name" {
  description = "key ring name"
}