terraform {
  cloud {
    organization = "jaxcb7e5133"

    workspaces {
      name = "kube-cluster"
    }
  }
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.1.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.2"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.10.0"
    }
  }
}

###
# Talos Kubernetes Cluster
###

provider "kubernetes" {
  host                   = yamldecode(talos_cluster_kubeconfig.kubeconfig.kube_config)["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(yamldecode(talos_cluster_kubeconfig.kubeconfig.kube_config)["clusters"][0]["cluster"]["certificate-authority-data"])
  client_certificate     = base64decode(yamldecode(talos_cluster_kubeconfig.kubeconfig.kube_config)["users"][0]["user"]["client-certificate-data"])
  client_key             = base64decode(yamldecode(talos_cluster_kubeconfig.kubeconfig.kube_config)["users"][0]["user"]["client-key-data"])
}

provider "kubectl" {
  host                   = yamldecode(talos_cluster_kubeconfig.kubeconfig.kube_config)["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(yamldecode(talos_cluster_kubeconfig.kubeconfig.kube_config)["clusters"][0]["cluster"]["certificate-authority-data"])
  client_certificate     = base64decode(yamldecode(talos_cluster_kubeconfig.kubeconfig.kube_config)["users"][0]["user"]["client-certificate-data"])
  client_key             = base64decode(yamldecode(talos_cluster_kubeconfig.kubeconfig.kube_config)["users"][0]["user"]["client-key-data"])
  load_config_file       = false
}

provider "talos" {}

resource "talos_machine_secrets" "machine_secrets" {}

data "talos_machine_configuration" "machineconfig_cp" {
  cluster_name         = var.cluster_name
  cluster_endpoint     = var.cluster_endpoint
  machine_type         = "controlplane"
  talos_version        = talos_machine_secrets.machine_secrets.talos_version
  machine_secrets      = talos_machine_secrets.machine_secrets.machine_secrets
}

data "talos_machine_configuration" "machineconfig_worker" {
  cluster_name         = var.cluster_name
  cluster_endpoint     = var.cluster_endpoint
  machine_type         = "worker"
  talos_version        = talos_machine_secrets.machine_secrets.talos_version
  machine_secrets      = talos_machine_secrets.machine_secrets.machine_secrets
}


data "talos_client_configuration" "talosconfig" {
  cluster_name    = var.cluster_name
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  endpoints       = [for k, v in var.node_data.controlplanes : k]
}

resource "talos_machine_configuration_apply" "cp_config_apply" {
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machineconfig_cp.machine_configuration
  for_each              = var.node_data.controlplanes
  endpoint              = each.key
  node                  = each.key
  config_patches = [
    templatefile("${path.module}/templates/install-disk-and-hostname.yaml.tmpl", {
      hostname     = each.value.hostname == null ? format("%s-cp-%s", var.cluster_name, index(keys(var.node_data.controlplanes), each.key)) : each.value.hostname
      install_disk = each.value.install_disk
    }),
    file("${path.module}/files/cp-scheduling.yaml"),
    file("${path.module}/files/cp-vip.yaml"),
    file("${path.module}/files/podsecuritypolicy.yaml"),
    file("${path.module}/files/node-config-all.yaml"),
    file("${path.module}/files/cluster-extramanifests.yaml")
  ]
}

resource "talos_machine_configuration_apply" "worker_config_apply" {
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machineconfig_worker.machine_configuration
  for_each              = var.node_data.workers
  endpoint              = each.key
  node                  = each.key
  config_patches = [
    templatefile("${path.module}/templates/install-disk-and-hostname.yaml.tmpl", {
      hostname     = each.value.hostname == null ? format("%s-worker-%s", var.cluster_name, index(keys(var.node_data.workers), each.key)) : each.value.hostname
      install_disk = each.value.install_disk
    }),
    file("${path.module}/files/node-config-all.yaml"),
  ]
}

resource "talos_machine_bootstrap" "bootstrap" {
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  endpoint     = [for k, v in var.node_data.controlplanes : k][0]
  node         = [for k, v in var.node_data.controlplanes : k][0]
}

data "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on = [
    talos_machine_bootstrap.bootstrap
  ]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  endpoint     = [for k, v in var.node_data.controlplanes : k][0]
  node         = [for k, v in var.node_data.controlplanes : k][0]
}

resource "null_resource" "config_output" {
  depends_on = [
    talos_machine_secrets.machine_secrets,
    talos_machine_bootstrap.bootstrap
  ]
  provisioner "local-exec" {
    command = "terraform output --raw kubeconfig > ../../kubeconfig && terraform output talosconfig > ../../talosconfig"
  }
}
