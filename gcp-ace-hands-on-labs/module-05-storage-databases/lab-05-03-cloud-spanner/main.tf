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

resource "google_spanner_instance" "main" {
  name         = var.instance_name
  config       = var.instance_config
  display_name = "ACE Hands On Labs - Spanner"

  force_destroy = true

  instance_type = "FREE_INSTANCE"
}

