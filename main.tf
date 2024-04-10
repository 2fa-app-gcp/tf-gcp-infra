provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project_id
  region      = var.region
}


provider "google-beta" {
  credentials = file(var.credentials_file)
  project     = var.project_id
  region      = var.region
}

resource "google_kms_key_ring" "key_ring" {
  name     = "key-ring-${formatdate("YYYYMMDDHHmmss", timestamp())}"
  location = var.region
  provider = google-beta
}

resource "google_kms_crypto_key" "vm_key" {
  name            = "vm-key"
  key_ring        = google_kms_key_ring.key_ring.id
  rotation_period = "2592000s"
  provider        = google-beta
}

resource "google_kms_crypto_key" "sql_key" {
  name            = "sql-key"
  key_ring        = google_kms_key_ring.key_ring.id
  rotation_period = "2592000s"
  provider        = google-beta
}

resource "google_kms_crypto_key" "storage_key" {
  name            = "storage-key"
  key_ring        = google_kms_key_ring.key_ring.id
  rotation_period = "2592000s"
  provider        = google-beta
}

resource "google_storage_bucket" "serverless_bucket" {
 name= var.bucket_name
 location = var.region
  encryption {
    default_kms_key_name = google_kms_crypto_key.storage_key.id
  }
  force_destroy = true
  public_access_prevention = "enforced"
  depends_on = [google_kms_crypto_key.storage_key,
  google_kms_crypto_key_iam_binding.binding,
  ]
}

resource "google_storage_bucket_object" "serverless_bucket_object" {
  name   = var.file_name
  bucket = google_storage_bucket.serverless_bucket.name
  source = "./Archive.zip"  
  depends_on = [ google_storage_bucket.serverless_bucket ]
}

resource "google_storage_bucket_iam_binding" "storage_bucket_iam_binding" {
  bucket = google_storage_bucket.serverless_bucket.name
  role   = "roles/storage.admin"
  members = [
    "serviceAccount:${google_service_account.log_account.email}",
    
  ]
}


resource "google_compute_network" "my_vpc" {
  name                            = "${var.environment}-${var.vpc_name}"
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
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
  name             = "${var.environment}-default-route"
  network          = google_compute_network.my_vpc.name
  dest_range       = var.default_route_dest_range
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_firewall" "allow_internet" {
  name     = "${var.environment}-allow-internet"
  network  = google_compute_network.my_vpc.name
  priority = 800
  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["http"]
}


resource "google_vpc_access_connector" "cloud_function_connector" {
  name          = "cloud-function-connector"
  region        = var.region
  ip_cidr_range = var.serverless_connector_ip_range
  network       = google_compute_network.my_vpc.self_link
}

resource "google_pubsub_topic" "example_topic" {
  name                       = var.topic
  message_retention_duration = "604800s"
}

resource "google_cloudfunctions_function" "mail_function" {
  name                  = var.function_name
  description           = "a new function"
  region                = var.region
  runtime               = "nodejs20"
  source_archive_bucket = google_storage_bucket.serverless_bucket.name
  source_archive_object = google_storage_bucket_object.serverless_bucket_object.name
  entry_point           = "helloPubSub"

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.example_topic.name
  }

  environment_variables = {
    HOST     = google_sql_database_instance.main.private_ip_address
    USERNAME = google_sql_user.users.name
    PASSWORD = random_password.pwd.result
    DATABASE = google_sql_database.main.name
    APIKEY   =  var.apikey
    DOMAIN_NAME = var.domain
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
  name     = "${var.environment}-deny-ssh"
  network  = google_compute_network.my_vpc.name
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

resource "google_compute_global_address" "lb_global_address" {
  project = var.project_id
  name    = "load-balancer-address"
}
resource "google_compute_region_instance_template" "myinstance" {
  name                    = "${var.environment}-webapp"
  machine_type            = var.machine_type
  depends_on              = [google_sql_user.users, google_pubsub_topic.example_topic]
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

  disk {
    source_image = var.image
    auto_delete  = true
    disk_size_gb = var.size
    disk_type    = var.type
    disk_encryption_key {
      kms_key_self_link = google_kms_crypto_key.vm_key.id
    }
  }
  service_account {
    email  = google_service_account.log_account.email
    scopes = ["https://www.googleapis.com/auth/logging.admin", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/pubsub"]
  }

  tags = ["http"]
}

resource "google_compute_health_check" "webapp_health_check" {
  name                = "webapp-health-check"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port         = "3000"
    port_name    = "http"
    request_path = "/healthz"
  }
  log_config {
    enable = true
  }
}

resource "google_compute_region_autoscaler" "autoscaler" {
  name   = "webapp-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.instance_group_manager.self_link
  autoscaling_policy {
    min_replicas    = 3
    max_replicas    = 6
    cooldown_period = 100
    cpu_utilization {
      target = 0.05
    }
  }
}

resource "google_compute_region_instance_group_manager" "instance_group_manager" {
  name                      = "instance-group-manager"
  base_instance_name        = "webappinstance"
  region                    = var.region
  distribution_policy_zones = [var.zone]

  version {
    instance_template = google_compute_region_instance_template.myinstance.self_link
  }

  named_port {
    name = "http"
    port = 3000
  }
  auto_healing_policies {
    health_check      = google_compute_health_check.webapp_health_check.self_link
    initial_delay_sec = 50
  }

  depends_on = [
    google_compute_region_instance_template.myinstance,
    google_compute_health_check.webapp_health_check
  ]
}


resource "google_compute_managed_ssl_certificate" "ssl_certificate_lb" {

  name = "ssl-certificate-lb"
  managed {
    domains = [var.domain_name]
  }

}

resource "google_compute_backend_service" "backend_service" {
  name                  = "backend-service"
  health_checks         = [google_compute_health_check.webapp_health_check.self_link]
  enable_cdn            = false
  protocol              = "HTTP"
  timeout_sec           = 60
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  backend {
    group           = google_compute_region_instance_group_manager.instance_group_manager.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

}

resource "google_compute_url_map" "url_map" {
  name            = "url-map"
  default_service = google_compute_backend_service.backend_service.self_link
}

resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "https-proxy"
  url_map          = google_compute_url_map.url_map.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.ssl_certificate_lb.id]
}

resource "google_compute_global_forwarding_rule" "webapp_lb_forwarding_rule_https" {
  name                  = "webapp-lb-forwarding-rule"
  ip_address            = google_compute_global_address.lb_global_address.id
  ip_protocol           = "TCP"
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL"
  target                = google_compute_target_https_proxy.https_proxy.self_link
}

resource "google_dns_record_set" "A_record" {
  name         = var.domain_name
  type         = "A"
  ttl          = 50
  managed_zone = var.managed_zone
  rrdatas      = [google_compute_global_address.lb_global_address.address]

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
  name                = "main-instance-${random_id.db_name_suffix.hex}"
  database_version    = "MYSQL_8_0"
  depends_on          = [google_service_networking_connection.private_vpc_connection]
  region              = var.region
  deletion_protection = var.deletion_protection
  encryption_key_name = google_kms_crypto_key.sql_key.id
  settings {
    tier              = var.tier
    disk_type         = var.disk_type
    disk_size         = var.disk_size
    availability_type = var.availability_type
    backup_configuration {
      binary_log_enabled = true
      enabled            = true
    }
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.my_vpc.self_link
      enable_private_path_for_google_cloud_services = true
    }
  }
}

resource "google_sql_database" "main" {
  name     = var.database_name
  instance = google_sql_database_instance.main.name
  project  = google_sql_database_instance.main.project
}
resource "random_password" "pwd" {
  length  = 16
  special = false
}

resource "google_sql_user" "users" {
  name       = "user"
  instance   = google_sql_database_instance.main.name
  password   = random_password.pwd.result
  depends_on = [google_sql_database.main]
}


# resource "google_dns_record_set" "root_domain" {
#   name         = var.domain_name
#   type         = "A"
#   ttl          = 300
#   managed_zone = var.managed_zone
#   rrdatas = [google_compute_instance.myinstance.network_interface.0.access_config.0.nat_ip]
# }

resource "google_project_iam_binding" "binding" {
  project = var.project_id
  role    = "roles/logging.admin"
  members = [
    "serviceAccount:${google_compute_region_instance_template.myinstance.service_account.0.email}"
  ]
}

resource "google_project_iam_binding" "binding_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"

  members = [
    "serviceAccount:${google_compute_region_instance_template.myinstance.service_account.0.email}"
  ]
}
resource "google_project_iam_binding" "binding_pubsub" {
  project = var.project_id
  role    = "roles/pubsub.publisher"

  members = [
    "serviceAccount:${google_compute_region_instance_template.myinstance.service_account.0.email}"
  ]
}

resource "google_project_iam_member" "pubsub_cloud_function_invoker" {
  project = var.project_id
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_compute_region_instance_template.myinstance.service_account.0.email}"
}

resource "google_project_iam_member" "token_creator_binding" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_compute_region_instance_template.myinstance.service_account.0.email}"
}

resource "google_storage_bucket_iam_member" "function_gcs_access" {
  bucket = var.bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.log_account.email}"
  depends_on = [google_storage_bucket_object.serverless_bucket_object]
}

resource "google_pubsub_subscription" "processEvent_subscription" {
  name                    = "processEvent_subscription"
  topic                   = google_pubsub_topic.example_topic.name
  ack_deadline_seconds    = 20
  enable_message_ordering = true
}


resource "google_kms_crypto_key_iam_binding" "vm_crypto_key_iam_binding" {
  crypto_key_id = google_kms_crypto_key.vm_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${var.vm_account}",
  ]
}

resource "google_kms_crypto_key_iam_binding" "csql_crypto_key_iam_binding" {
  crypto_key_id = google_kms_crypto_key.sql_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${google_project_service_identity.gcp_sa_cloud_sql.email}",
  ]
}
data "google_storage_project_service_account" "gcs_account" {
}

resource "google_kms_crypto_key_iam_binding" "binding" {
  crypto_key_id = google_kms_crypto_key.storage_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = ["serviceAccount:${var.binding_account}"]
}


resource "google_project_service_identity" "gcp_sa_cloud_sql" {
  provider = google-beta
  service  = "sqladmin.googleapis.com"
}
