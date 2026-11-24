output "service_vm_internal_ip" {
  value = google_compute_instance.service_vm.network_interface[0].network_ip
}

output "service_vm_name" {
  value = google_compute_instance.service_vm.name
}