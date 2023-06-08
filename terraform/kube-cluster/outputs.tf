output "machineconfig_controlplane" {
  value     = data.talos_machine_configuration.machineconfig_cp
  sensitive = true
}

output "machineconfig_worker" {
  value     = data.talos_machine_configuration.machineconfig_worker
  sensitive = true
}

output "talosconfig" {
  value     = data.talos_client_configuration.talosconfig.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = data.talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
}
