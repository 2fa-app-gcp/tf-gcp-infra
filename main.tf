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

resource "google_compute_firewall" "deny_ssh" {
  name    = "${var.environment}-deny-ssh"
  network = google_compute_network.my_vpc.name
  priority = 1000
  deny {
    protocol = "tcp"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "myinstance" {
  name = "${var.environment}-webapp-${formatdate("YYYYMMDDHHmmss", timestamp())}"

  machine_type = var.machine_type
  zone         = var.zone

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
