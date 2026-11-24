variable "project_id" {
  description = "ID do projeto GCP"
  type        = string
}

variable "region" {
  description = "Região do bucket"
  type        = string
  default     = "US-CENTRAL1"
}

variable "bucket_name" {
  description = "Nome globalmente único do bucket"
  type        = string
}
