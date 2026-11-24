output "node_template_name" {
  description = "Nome do Node Template"
  value       = google_compute_node_template.ace_node_template.name
}

output "node_group_name" {
  description = "Nome do Node Group"
  value       = google_compute_node_group.ace_node_group.name
}

output "maintenance_policy" {
  description = "Política de manutenção do Node Group"
  value       = google_compute_node_group.ace_node_group.maintenance_policy
}
