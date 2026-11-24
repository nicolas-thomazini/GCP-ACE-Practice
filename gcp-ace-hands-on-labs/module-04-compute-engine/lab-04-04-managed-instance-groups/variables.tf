variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Google Cloud zone"
  type        = string
  default     = "us-central1-a"
}

variable "instance_template_name" {
  description = "Existing Compute Engine Instance Template"
  type        = string
  default     = "ace-instance-template"
}
