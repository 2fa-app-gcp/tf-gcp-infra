provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project_id
  region      = var.region
}

resource "google_compute_network" "my_vpc" {
  name                    = "${var.environment}-${var.vpc_name}"
  auto_create_subnetworks = false
  routing_mode            = var.routing_mode
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "webapp" {
  name          = "webapp"
  network       = google_compute_network.my_vpc.self_link
  ip_cidr_range = var.webapp_subnet_cidr
}

resource "google_compute_subnetwork" "db" {
  name          = "db"
  network       = google_compute_network.my_vpc.self_link
  ip_cidr_range = var.db_subnet_cidr
}

resource "google_compute_route" "default_route" {
  name                  = "${var.environment}-default-route"
  network               = google_compute_network.my_vpc.name
  dest_range            = var.default_route_dest_range
  next_hop_gateway      = "default-internet-gateway"
}

resource "google_compute_firewall" "allow_internet" {
  name    = "${var.environment}-allow-internet"
  network = google_compute_network.my_vpc.name
  priority = 800
  allow {
    protocol = "tcp"
    ports    = ["3000","22"]  
  }

  source_ranges = ["0.0.0.0/0"]
}

# resource "google_compute_firewall" "allow_ssh" {
#   name    = "${var.environment}-allow-ssh"
#   network = google_compute_network.my_vpc.name
#   priority = 801
#   allow {
#     protocol = "tcp"
#     ports    = ["22"]  
#   }

#   source_ranges = ["0.0.0.0/0"]
# }

# a Serverless VPC Access connector
resource "google_vpc_access_connector" "cloud_function_connector" {
  name         = "cloud-function-connector"
  region       = var.region
  ip_cidr_range = var.serverless_connector_ip_range  
  network      = google_compute_network.my_vpc.self_link
}

resource "google_pubsub_topic" "example_topic" {
  name = var.topic
  message_retention_duration ="604800s"
}

resource "google_cloudfunctions_function" "mail_function" {
  name        = var.function_name
  description = "a new function"
  region      = var.region

  runtime     = "nodejs20"

  source_archive_bucket = var.bucket_name
  source_archive_object = var.file_name
  entry_point = "helloPubSub"  

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.example_topic.name
  }

  environment_variables = {
    HOST     = google_sql_database_instance.main.private_ip_address
    USERNAME = google_sql_user.users.name
    PASSWORD = random_password.pwd.result
    DATABASE = google_sql_database.main.name
  }

  service_account_email = google_service_account.log_account.email

  vpc_connector = google_vpc_access_connector.cloud_function_connector.name

  depends_on = [
    google_sql_database_instance.main,
    google_pubsub_topic.example_topic,
    google_vpc_access_connector.cloud_function_connector
  ]
}

resource "google_compute_firewall" "deny_ssh" {
  name    = "${var.environment}-deny-ssh"
  network = google_compute_network.my_vpc.name
  priority = 1000
  deny {
    protocol = "tcp"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_service_account" "log_account" {
  account_id   = var.account_id
  display_name = "Service Account"
}
resource "google_compute_instance" "myinstance" {
  name = "${var.environment}-webapp-${formatdate("YYYYMMDDHHmmss", timestamp())}"
  machine_type = var.machine_type
  zone         = var.zone
  depends_on = [ google_sql_user.users,google_pubsub_topic.example_topic ]
  allow_stopping_for_update=true
  metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    # Download secrets file and place it in /opt/webapp/secrets
    mkdir -p /opt/webapp/secrets
    
    rm -f /opt/webapp/secrets/secrets.env && echo "HOST=${google_sql_database_instance.main.private_ip_address}" > /opt/webapp/secrets/secrets.env
    echo "USERNAME=${google_sql_user.users.name}" >> /opt/webapp/secrets/secrets.env
    echo "PASSWORD=${google_sql_user.users.password}" >> /opt/webapp/secrets/secrets.env
    echo "DATABASE=${google_sql_database.main.name}">> /opt/webapp/secrets/secrets.env
    echo "startup=true" >> /opt/webapp/secrets/secrets.env
    echo "TOPIC=${var.topic}" >> /opt/webapp/secrets/secrets.env
    echo "PROJECT_ID=${var.project_id}" >> /opt/webapp/secrets/secrets.env
    sudo  systemctl start node
  SCRIPT
  network_interface {
    subnetwork = google_compute_subnetwork.webapp.name
    access_config {
      network_tier = "PREMIUM"
    }
  }

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.size
      type  = var.type
    }
    
  }
  service_account {
    email= google_service_account.log_account.email
    scopes = ["https://www.googleapis.com/auth/logging.admin","https://www.googleapis.com/auth/monitoring.write","https://www.googleapis.com/auth/pubsub"]
  }
  
}

resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_compute_global_address" "private_ip_address" {
  project       = var.project_id
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.my_vpc.name
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.my_vpc.name
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}



resource "google_sql_database_instance" "main" {
  name             = "main-instance-${random_id.db_name_suffix.hex}"
  database_version = "MYSQL_8_0"
  depends_on = [ google_service_networking_connection.private_vpc_connection ]
  region     = var.region
  deletion_protection= var.deletion_protection
  
  settings {
    tier = var.tier
    disk_type = var.disk_type
    disk_size = var.disk_size
    availability_type = var.availability_type
    backup_configuration {
      binary_log_enabled = true 
      enabled = true
    }
    ip_configuration {
      ipv4_enabled = false
      private_network =  google_compute_network.my_vpc.self_link
      enable_private_path_for_google_cloud_services = true
    }
  }
  
}

resource "google_sql_database" "main" {
  name       = var.database_name
  instance   = google_sql_database_instance.main.name
  project    = google_sql_database_instance.main.project
}
resource "random_password" "pwd" {
  length  = 16
  special = false
}

resource "google_sql_user" "users" {
  name     = "user"
  instance = google_sql_database_instance.main.name
  password = random_password.pwd.result
  depends_on = [google_sql_database.main] 
}


resource "google_dns_record_set" "root_domain" {
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  managed_zone = var.managed_zone
  rrdatas = [google_compute_instance.myinstance.network_interface.0.access_config.0.nat_ip]
}

resource "google_project_iam_binding" "binding" {
  project = var.project_id
  role    = "roles/logging.admin"
  members = [
    "serviceAccount:${google_compute_instance.myinstance.service_account.0.email}"
  ]
}

resource "google_project_iam_binding" "binding_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  
  members = [
    "serviceAccount:${google_compute_instance.myinstance.service_account.0.email}"
  ]
}
resource "google_project_iam_binding" "binding_pubsub" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  
  members = [
    "serviceAccount:${google_compute_instance.myinstance.service_account.0.email}"
  ]
}

resource "google_project_iam_member" "pubsub_cloud_function_invoker" {
  project = var.project_id
  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${google_compute_instance.myinstance.service_account.0.email}"
}

resource "google_project_iam_member" "token_creator_binding" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_compute_instance.myinstance.service_account.0.email}"
}

resource "google_storage_bucket_iam_member" "function_gcs_access" {
  bucket = "mailfunction-csye6225"
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_compute_instance.myinstance.service_account.0.email}"
}

resource "google_pubsub_subscription" "processEvent_subscription" {
  name  = "processEvent_subscription"
  topic = google_pubsub_topic.example_topic.name

  ack_deadline_seconds = 20

  push_config {
    push_endpoint = "https://${var.region}-${var.project_id}.cloudfunctions.net/${google_cloudfunctions_function.mail_function.name}"
    oidc_token {
      # a new IAM service account is need to allow the subscription to trigger the function
      service_account_email = google_service_account.log_account.email
    }
  }
  enable_message_ordering = true
}