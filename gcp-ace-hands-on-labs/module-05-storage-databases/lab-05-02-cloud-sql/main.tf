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

resource "google_sql_database_instance" "postgres" {
  name             = var.instance_name
  region           = var.region
  database_version = "POSTGRES_16"

  deletion_protection = false

  settings {
    edition           = "ENTERPRISE"
    tier              = "db-f1-micro"
    availability_type = "ZONAL"

    disk_type       = "PD_HDD"
    disk_size       = 10
    disk_autoresize = false

    ip_configuration {
      ipv4_enabled = true
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "03:55"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }

    user_labels = {
      environment = "learning"
      module      = "module-05"
      lab         = "lab-05-02"
    }
  }
}

resource "google_sql_database" "database" {
  name     = "ace_lab"
  instance = google_sql_database_instance.postgres.name
}

