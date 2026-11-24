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

resource "google_compute_disk" "data_disk" {
  name = "ace-data-disk"
  type = "pd-balanced"
  zone = var.zone
  size = 10

  labels = {
    environment = "lab"
    module      = "compute-engine"
  }
}

resource "google_compute_snapshot" "data_disk_snapshot" {
  name        = "ace-data-disk-snapshot"
  source_disk = google_compute_disk.data_disk.name
  zone        = var.zone

  labels = {
    environment = "lab"
    module      = "compute-engine"
  }

  storage_locations = ["us"]
}

resource "google_compute_disk" "restored_disk" {
  name = "ace-restored-disk"
  type = "pd-balanced"
  zone = var.zone

  snapshot = google_compute_snapshot.data_disk_snapshot.self_link

  labels = {
    environment = "lab"
    module      = "compute-engine"
  }
}

resource "google_compute_instance" "disk_lab_vm" {
  name         = "ace-disk-lab-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }

  attached_disk {
    source      = google_compute_disk.data_disk.id
    device_name = "ace-data-disk"
  }

  attached_disk {
    source      = google_compute_disk.restored_disk.id
    device_name = "ace-restored-disk"
  }

  network_interface {
    network = "default"
  }

  tags = ["ace-disk-lab"]

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

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "ace-disk-lab-allow-iap-ssh"
  network = "default"

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["ace-disk-lab"]
}

