terraform {
  cloud {
    organization = "jaxcb7e5133"

    workspaces {
      name = "flux"
    }
  }
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.2"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.10.0"
    }
    github = {
      source  = "integrations/github"
      version = ">= 4.5.2"
    }
    flux = {
      source = "fluxcd/flux"
      version = "1.6.4"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.1.0"
    }
  }
}

data "tfe_outputs" "kubeconfig" {
  organization = "jaxcb7e5133"
  workspace    = "kube-cluster"
}

provider "kubernetes" {
  host                   = yamldecode(data.tfe_outputs.kubeconfig.values.kubeconfig)["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(yamldecode(data.tfe_outputs.kubeconfig.values.kubeconfig)["clusters"][0]["cluster"]["certificate-authority-data"])
  client_certificate     = base64decode(yamldecode(data.tfe_outputs.kubeconfig.values.kubeconfig)["users"][0]["user"]["client-certificate-data"])
  client_key             = base64decode(yamldecode(data.tfe_outputs.kubeconfig.values.kubeconfig)["users"][0]["user"]["client-key-data"])
}

provider "kubectl" {
  host                   = yamldecode(data.tfe_outputs.kubeconfig.values.kubeconfig)["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(yamldecode(data.tfe_outputs.kubeconfig.values.kubeconfig)["clusters"][0]["cluster"]["certificate-authority-data"])
  client_certificate     = base64decode(yamldecode(data.tfe_outputs.kubeconfig.values.kubeconfig)["users"][0]["user"]["client-certificate-data"])
  client_key             = base64decode(yamldecode(data.tfe_outputs.kubeconfig.values.kubeconfig)["users"][0]["user"]["client-key-data"])
}

# Kubernetes Namespace
resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
    ]
  }
}

provider "github" {
  owner = var.gh_owner
  token = var.gh_token
}

variable "repository_name" {
  type        = string
  default     = "CloudHub-Cluster"
  description = "github repository name"
}

resource "tls_private_key" "flux" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "github_repository_deploy_key" "this" {
  title      = "Flux"
  repository = var.repository_name
  key        = tls_private_key.flux.public_key_openssh
  read_only  = "false"
}

provider "flux" {
  kubernetes = {
    host                   = yamldecode(data.tfe_outputs.kubeconfig.values.kubeconfig)["clusters"][0]["cluster"]["server"]
    cluster_ca_certificate = base64decode(yamldecode(data.tfe_outputs.kubeconfig.values.kubeconfig)["clusters"][0]["cluster"]["certificate-authority-data"])
    client_certificate     = base64decode(yamldecode(data.tfe_outputs.kubeconfig.values.kubeconfig)["users"][0]["user"]["client-certificate-data"])
    client_key             = base64decode(yamldecode(data.tfe_outputs.kubeconfig.values.kubeconfig)["users"][0]["user"]["client-key-data"])
  }
  git = {
    url = "ssh://git@github.com/${var.gh_owner}/${var.repository_name}.git"
    ssh = {
      username    = "git"
      private_key = tls_private_key.flux.private_key_pem
    }
  }
}

resource "flux_bootstrap_git" "this" {
  depends_on = [github_repository_deploy_key.this]

  path = "cluster/production"
}

# resource "null_resource" "sops_secret" {
#   depends_on = [
#     flux_bootstrap_git.this
#   ]
#   provisioner "local-exec" {
#     command = "cat ~/.config/sops/age/age.agekey | kubectl create secret generic sops-age --namespace=flux-system --from-file=age.agekey=/dev/stdin"
#   }
# }
