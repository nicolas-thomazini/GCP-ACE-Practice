variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Default Google Cloud region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Compute Engine zone"
  type        = string
  default     = "us-central1-a"
}

variable "vpc_name" {
  description = "Existing VPC network name"
  type        = string
  default     = "ace-vpc-custom"
}

variable "subnet_name" {
  description = "Existing subnet name"
  type        = string
  default     = "ace-subnet-us-central1"
}
