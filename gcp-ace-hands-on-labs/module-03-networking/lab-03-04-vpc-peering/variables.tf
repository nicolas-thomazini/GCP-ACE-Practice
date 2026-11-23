variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Region for the peering VPC subnet"
  type        = string
}

variable "primary_vpc_name" {
  description = "Existing VPC network"
  type        = string
}

variable "secondary_vpc_name" {
  description = "New VPC network for peering"
  type        = string
}
