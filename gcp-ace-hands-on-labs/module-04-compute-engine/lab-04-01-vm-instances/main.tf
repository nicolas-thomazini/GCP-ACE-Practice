terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "ace-vm-allow-iap-ssh"
  network = "default"

  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["ace-vm"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_instance" "vm" {
  name         = "ace-vm-instance"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["ace-vm"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  labels = {
    environment = "lab"
    module      = "compute-engine"
  }

  depends_on = [
    google_compute_firewall.allow_iap_ssh
  ]
}

