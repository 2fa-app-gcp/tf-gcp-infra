variable "project_id" {
  description = "GCP project ID"
}

variable "region" {
  description = "GCP region"
}

variable "credentials_file" {
  description = "Path to GCP service account credentials JSON file"
}

variable "vpc_name" {
  description = "Name of the VPC"
  default     = "my-vpc"
}

variable "webapp_subnet_cidr" {
  description = "CIDR range for the webapp subnet"
  default     = "100.1.1.0/24"
}

variable "db_subnet_cidr" {
  description = "CIDR range for the db subnet"
  default     = "100.1.2.0/24"
}


variable "default_route_dest_range" {
  description = "Destination IP range for the default route"
  default     = "0.0.0.0/0"
}


