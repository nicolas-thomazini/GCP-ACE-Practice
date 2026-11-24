terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_compute_network" "existing_vpc" {
  name = var.vpc_name
}

data "google_compute_subnetwork" "existing_subnet" {
  name   = var.subnet_name
  region = var.region
}

resource "google_compute_instance" "nat_test_vm" {
  name         = "ace-cloud-nat-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.existing_subnet.id
    # Sem access_config: nenhum IP público
  }

  tags = ["cloud-nat-test"]
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name      = "ace-cloud-nat-allow-iap-ssh"
  network   = data.google_compute_network.existing_vpc.name
  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["cloud-nat-test"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_router" "nat_router" {
  name    = "ace-cloud-nat-router"
  region  = var.region
  network = data.google_compute_network.existing_vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "ace-cloud-nat"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = data.google_compute_subnetwork.existing_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ALL"
  }
}

