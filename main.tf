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
    ports    = ["3000"]  
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.environment}-allow-ssh"
  network = google_compute_network.my_vpc.name
  priority = 801
  allow {
    protocol = "tcp"
    ports    = ["22"]  
  }

  source_ranges = ["0.0.0.0/0"]
}

# resource "google_compute_firewall" "deny_ssh" {
#   name    = "${var.environment}-deny-ssh"
#   network = google_compute_network.my_vpc.name
#   priority = 1000
#   deny {
#     protocol = "tcp"
#   }

#   source_ranges = ["0.0.0.0/0"]
# }

resource "google_compute_instance" "myinstance" {
  name = "${var.environment}-webapp-${formatdate("YYYYMMDDHHmmss", timestamp())}"
  machine_type = var.machine_type
  zone         = var.zone
  depends_on = [ google_sql_user.users ]

   metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    # Download secrets file and place it in /opt/webapp/secrets
    mkdir -p /opt/webapp/secrets
    
    rm -f /opt/webapp/secrets/secrets.env && echo "HOST=${google_sql_database_instance.main.private_ip_address}" > /opt/webapp/secrets/secrets.env
    echo "USERNAME=${google_sql_user.users.name}" >> /opt/webapp/secrets/secrets.env
    echo "PASSWORD=${google_sql_user.users.password}" >> /opt/webapp/secrets/secrets.env
    echo "DATABASE=${google_sql_database.main.name}">> /opt/webapp/secrets/secrets.env
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
  deletion_protection= false
  
  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled = false
      private_network =  google_compute_network.my_vpc.self_link
      enable_private_path_for_google_cloud_services = true
    }
  }
}

resource "google_sql_database" "main" {
  name       = "webapp"
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

