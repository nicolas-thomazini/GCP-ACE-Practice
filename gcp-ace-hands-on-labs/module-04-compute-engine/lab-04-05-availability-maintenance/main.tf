terraform {
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
}

resource "google_compute_node_template" "ace_node_template" {
  name   = "ace-sole-tenant-template"
  region = var.region

  node_type = "c2-node-60-240"

  description = "Template de estudo para Sole-Tenant Nodes"
}

resource "google_compute_node_group" "ace_node_group" {
  name          = "ace-sole-tenant-group"
  zone          = var.zone
  node_template = google_compute_node_template.ace_node_template.self_link

  initial_size       = var.node_group_size
  maintenance_policy = "DEFAULT"

  description = "Node Group de estudo para certificação ACE"
}

