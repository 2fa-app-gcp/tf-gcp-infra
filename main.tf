provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project_id
  region      = var.region
}

resource "google_compute_network" "my_vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "
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
  name                  = "default-route"
  network               = google_compute_network.my_vpc.name
  dest_range            = var.default_route_dest_range
  next_hop_gateway      = google_compute_network.my_vpc.gateway_ipv4
}


