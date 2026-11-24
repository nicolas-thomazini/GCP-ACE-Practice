variable "project_id" {
  description = "ID do projeto Google Cloud"
  type        = string
}

variable "region" {
  description = "Região dos recursos"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zona do Node Group"
  type        = string
  default     = "us-central1-a"
}

variable "node_type" {
  description = "Tipo de hardware do Sole-Tenant Node"
  type        = string
  default     = "c2-node-60-240"
}

variable "node_group_size" {
  description = "Quantidade inicial de nós físicos"
  type        = number
  default     = 1
}
