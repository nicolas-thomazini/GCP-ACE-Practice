variable "project_id" {
  description = "ID do projeto GCP"
  type        = string
}

variable "region" {
  description = "Região do laboratório"
  type        = string
  default     = "us-central1"
}

variable "instance_name" {
  description = "ID da instância Spanner"
  type        = string
}

variable "instance_config" {
  description = "Configuração regional da instância"
  type        = string
  default     = "regional-us-central1"
}
