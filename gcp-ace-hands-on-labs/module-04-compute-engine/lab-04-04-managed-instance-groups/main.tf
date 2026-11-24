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

data "google_compute_instance_template" "ace_template" {
  name = var.instance_template_name
}

resource "google_compute_instance_group_manager" "ace_mig" {
  name               = "ace-managed-instance-group"
  zone               = var.zone
  base_instance_name = "ace-mig-vm"

  version {
    instance_template = data.google_compute_instance_template.ace_template.self_link
  }

  target_size = 2

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 1
    max_unavailable_fixed = 0
  }
}

resource "google_compute_autoscaler" "ace_autoscaler" {
  name   = "ace-mig-autoscaler"
  zone   = var.zone
  target = google_compute_instance_group_manager.ace_mig.id

  autoscaling_policy {
    min_replicas    = 2
    max_replicas    = 4
    cooldown_period = 60

    cpu_utilization {
      target = 0.60
    }
  }
}

resource "google_compute_firewall" "ace_iap_ssh" {
  name    = "ace-mig-allow-iap-ssh"
  network = "default"

  direction = "INGRESS"

  source_ranges = [
    "35.235.240.0/20"
  ]

  target_tags = ["ace-template"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

