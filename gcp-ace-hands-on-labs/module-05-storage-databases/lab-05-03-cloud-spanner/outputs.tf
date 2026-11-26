output "instance_name" {
  description = "Nome da instância Cloud Spanner"
  value       = google_spanner_instance.main.name
}

output "instance_config" {
  description = "Configuração regional da instância"
  value       = google_spanner_instance.main.config
}

output "instance_type" {
  description = "Tipo da instância"
  value       = google_spanner_instance.main.instance_type
}
