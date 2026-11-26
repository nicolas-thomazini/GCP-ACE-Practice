variable "project_id" {
  description = "ID do projeto GCP"
  type        = string
}

variable "region" {
  description = "Região da instância Cloud SQL"
  type        = string
  default     = "us-central1"
}

variable "instance_name" {
  description = "Nome da instância PostgreSQL"
  type        = string
}
