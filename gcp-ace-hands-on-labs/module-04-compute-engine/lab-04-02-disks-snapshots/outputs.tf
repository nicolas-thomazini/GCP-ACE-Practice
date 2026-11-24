output "snapshot_name" {
  description = "Name of the disk snapshot"
  value       = google_compute_snapshot.data_disk_snapshot.name
}

output "restored_disk_name" {
  description = "Name of the disk restored from snapshot"
  value       = google_compute_disk.restored_disk.name
}

output "disk_lab_vm_name" {
  description = "Name of the disk lab VM"
  value       = google_compute_instance.disk_lab_vm.name
}

output "disk_lab_vm_internal_ip" {
  description = "Internal IP of the disk lab VM"
  value       = google_compute_instance.disk_lab_vm.network_interface[0].network_ip
}
