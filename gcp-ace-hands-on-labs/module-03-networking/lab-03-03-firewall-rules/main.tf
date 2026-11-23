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

resource "google_compute_instance" "firewall_vm" {
  name         = "ace-firewall-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  tags = ["web-server", "iap-ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.existing_subnet.id
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    mkdir -p /var/www/html
    echo "Hello from GCP Firewall Lab!" > /var/www/html/index.html
    nohup python3 -m http.server 8080 --directory /var/www/html --bind 0.0.0.0 > /var/log/firewall-server.log 2>&1 &
  EOF
}

resource "google_compute_instance" "client_vm" {
  name         = "ace-firewall-client"
  machine_type = "e2-micro"
  zone         = var.zone

  tags = ["iap-ssh", "firewall-client"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.existing_subnet.id
  }
}

resource "google_compute_firewall" "allow_http" {
  name      = "ace-allow-http-8080"
  network   = data.google_compute_network.existing_vpc.id
  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["10.10.0.0/23"]
  target_tags   = ["web-server"]

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
}

resource "google_compute_firewall" "allow_http_9090" {
  name      = "ace-allow-http-9090"
  network   = data.google_compute_network.existing_vpc.id
  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["10.10.0.0/23"]
  target_tags   = ["web-server"]

  allow {
    protocol = "tcp"
    ports    = ["9090"]
  }
}

resource "google_compute_firewall" "deny_http_8080" {
  name      = "ace-deny-http-8080"
  network   = data.google_compute_network.existing_vpc.id
  direction = "INGRESS"
  priority  = 900

  source_ranges = ["10.10.0.0/23"]
  target_tags   = ["web-server"]

  deny {
    protocol = "tcp"
    ports    = ["8080"]
  }
}

resource "google_compute_firewall" "deny_egress_9090" {
  name      = "ace-deny-egress-9090"
  network   = data.google_compute_network.existing_vpc.id
  direction = "EGRESS"
  priority  = 900

  destination_ranges = ["10.10.0.0/23"]
  target_tags        = ["firewall-client"]

  deny {
    protocol = "tcp"
    ports    = ["9090"]
  }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name      = "ace-allow-iap-ssh"
  network   = data.google_compute_network.existing_vpc.id
  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["iap-ssh"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
