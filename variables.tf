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
  default = "network-cloud-002277864"
}

variable "region" {
  description = "Google Cloud region"
}

variable "vpc_name" {
  description = "Name of the VPC"
  default = "my-vpc"
}

variable "routing_mode" {
  description = "Routing mode for the VPC"
  default     = "REGIONAL"
}

variable "webapp_subnet_cidr" {
  description = "CIDR range for the webapp subnetwork"
  default = "100.1.1.0/24"
}

variable "db_subnet_cidr" {
  description = "CIDR range for the db subnetwork"
  default = "100.1.2.0/24"
}

variable "default_route_dest_range" {
  description = "Destination range for the default route"
  default = "0.0.0.0/0"
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
  default     = "20"
}

variable "type" {
  description = "Type for the instance's boot disk"
  default     = "pd-balanced"
}
