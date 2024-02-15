# tf-gcp-infra
Repository for creating gcp infrastructure


# GCP APIS enabled


Google Cloud Storage API:

Purpose: store and retrieve files or backups associated with your web app, enabling the Cloud Storage API is essential.
Usage: This API allows your application to interact with Google Cloud Storage buckets.

Google Cloud Identity and Access Management (IAM) API:

Purpose: IAM is crucial for managing access control to your GCP resources.
Usage: need to manage IAM roles and permissions to ensure that your web app has the necessary access to MySQL and other GCP services.

Google Cloud Resource Manager API:

Purpose: This API helps manage your GCP resources by providing functionalities for creating, reading, and updating projects.
Usage: Enable this API for resource management tasks related to your project.

Google Cloud Logging API and Google Cloud Monitoring API:

Purpose: These APIs are used for logging and monitoring your application's performance and health.
Usage: Enable these APIs to gain insights into your application's behavior.

Google Cloud Compute Engine API:

Purpose: virtual machines or compute engine instances, you may need this API.
Usage: Enable this API for managing and interacting with virtual machines.

Google Cloud Backup:

Purpose :- Managed backup and disaster recovery (DR) service for centralized, application-consistent data protection.
Usage:- Protect workloads running in Google Cloud and on-premises by backing them up to Google Cloud.


# Terraform Infrastructure for Google Cloud Platform

This Terraform configuration defines the infrastructure for a web application project on Google Cloud Platform (GCP). The configuration includes the creation of a Virtual Private Cloud (VPC), subnetworks for a web application and a database, and a default route.

## Prerequisites

Before using this Terraform configuration, ensure you have the following prerequisites:

- [Terraform](https://www.terraform.io/) installed on your local machine.
- GCP service account credentials file (JSON format).
- GCP project ID with the necessary permissions to create resources.

## Configuration

1. Create a `terraform.tfvars` file with the following content:

   ```hcl
   credentials_file       = "path/to/your/credentials.json"
   project_id             = "your-gcp-project-id"
   region                 = "your-gcp-region"
   vpc_name               = "your-vpc-name"
   webapp_subnet_cidr     = "10.1.0.0/24"
   db_subnet_cidr         = "10.2.0.0/24"
   default_route_dest_range = "0.0.0.0/0"


2. Run the following commands to initialize and apply the Terraform configuration:

`terraform init
terraform apply`

3. To destroy the created resources, run:

`terraform destroy`