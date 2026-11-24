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
  project = var.host_project_id
  region  = var.region
}

provider "google" {
  alias   = "service"
  project = var.service_project_id
  region  = var.region
}

resource "google_compute_network" "shared_vpc" {
  name                    = "ace-shared-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "shared_subnet" {
  name          = "ace-shared-subnet"
  region        = var.region
  network       = google_compute_network.shared_vpc.id
  ip_cidr_range = "10.60.0.0/24"
}

resource "google_compute_instance" "service_vm" {
  provider     = google.service
  name         = "ace-shared-vpc-service-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.shared_subnet.id
  }
}

