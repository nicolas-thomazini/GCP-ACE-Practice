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

resource "google_compute_instance_template" "ace_template" {
  name        = "ace-instance-template"
  description = "Instance Template created for ACE hands-on lab"

  machine_type = "e2-small"

  tags = ["ace-template"]

  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true

    disk_size_gb = 10
    disk_type    = "pd-balanced"
  }

  network_interface {
    network = "default"
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  lifecycle {
    create_before_destroy = true
  }
}

