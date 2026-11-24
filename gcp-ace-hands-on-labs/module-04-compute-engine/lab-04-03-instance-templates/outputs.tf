output "instance_template_name" {
  description = "Name of the Compute Engine Instance Template"
  value       = google_compute_instance_template.ace_template.name
}

output "instance_template_id" {
  description = "ID of the Compute Engine Instance Template"
  value       = google_compute_instance_template.ace_template.id
}

output "instance_template_self_link" {
  description = "Self link of the Instance Template"
  value       = google_compute_instance_template.ace_template.self_link
}
