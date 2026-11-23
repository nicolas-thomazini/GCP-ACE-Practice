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

data "google_compute_network" "primary" {
  name = var.primary_vpc_name
}

resource "google_compute_network" "secondary" {
  name                    = var.secondary_vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "secondary_subnet" {
  name          = "ace-subnet-peering"
  region        = var.region
  network       = google_compute_network.secondary.id
  ip_cidr_range = "10.50.0.0/24"
}

resource "google_compute_network_peering" "primary_to_secondary" {
  name         = "ace-peering-primary-to-secondary"
  network      = data.google_compute_network.primary.self_link
  peer_network = google_compute_network.secondary.self_link
}

resource "google_compute_network_peering" "secondary_to_primary" {
  name         = "ace-peering-secondary-to-primary"
  network      = google_compute_network.secondary.self_link
  peer_network = data.google_compute_network.primary.self_link
}

resource "google_compute_firewall" "allow_icmp_primary" {
  name      = "ace-peering-allow-icmp-primary"
  network   = data.google_compute_network.primary.name
  direction = "INGRESS"

  source_ranges = ["10.50.0.0/24"]

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "allow_icmp_secondary" {
  name      = "ace-peering-allow-icmp-secondary"
  network   = google_compute_network.secondary.name
  direction = "INGRESS"

  source_ranges = [
    "10.10.0.0/23",
    "10.20.0.0/24"
  ]

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_instance" "vm_primary" {
  name         = "ace-peering-vm-1"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork = "ace-subnet-us-central1"
  }

  tags = ["peering-test"]
}

resource "google_compute_instance" "vm_secondary" {
  name         = "ace-peering-vm-2"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.secondary_subnet.id
  }

  tags = ["peering-test"]
}

resource "google_compute_firewall" "allow_iap_ssh_primary" {
  name      = "ace-peering-allow-iap-ssh-primary"
  network   = data.google_compute_network.primary.name
  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["peering-test"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_iap_ssh_secondary" {
  name      = "ace-peering-allow-iap-ssh-secondary"
  network   = google_compute_network.secondary.name
  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["peering-test"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

