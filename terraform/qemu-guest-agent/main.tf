terraform {
  cloud {
    organization = "jaxcb7e5133"

    workspaces {
      name = "qemu-guest-agent"
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

data "tfe_outputs" "kubeconfig" {
  organization = "jaxcb7e5133"
  workspace = "kube-cluster"
}

provider "kubernetes" {}

provider "kubectl" {}

###
# Qemu Guest Agent
###

resource "kubernetes_namespace" "qemu-guest-agent" {
  metadata {
    name = "qemu-guest-agent"
  }
}

resource "null_resource" "talosconfig-secret" {
  depends_on = [
    kubernetes_namespace.qemu-guest-agent
  ]
  provisioner "local-exec" {
    command = "kubectl create secret -n qemu-guest-agent generic talosconfig --from-file=config=../../talosconfig"
  }
}

data "kubectl_file_documents" "qemu-ga-talos" {
  content = file("${path.module}/files/qemu-ga-talos.yaml")
}

resource "kubectl_manifest" "qemu-ga-talos" {
  for_each  = data.kubectl_file_documents.qemu-ga-talos.manifests
  yaml_body = each.value
}
