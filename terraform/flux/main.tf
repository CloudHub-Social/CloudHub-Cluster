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
      source  = "fluxcd/flux"
      version = ">= 0.0.13"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "3.1.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = ">= 0.7.2"
    }
  }
}

data "sops_file" "secrets" {
  source_file = "secret.sops.yaml"
}

data "tfe_outputs" "kubeconfig" {
  organization = "jaxcb7e5133"
  workspace    = "kube-cluster"
}

provider "github" {
  owner = data.sops_file.secrets.data["gh_owner"]
  token = data.sops_file.secrets.data["gh_token"]
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
    url = "ssh://git@github.com/${data.sops_file.secrets.data["gh_owner"]}/${var.repository_name}.git"
    ssh = {
      username    = "git"
      private_key = tls_private_key.flux.private_key_pem
    }
  }
}

resource "flux_bootstrap_git" "this" {
  depends_on = [github_repository_deploy_key.this]

  path = "clusters/production"
}
