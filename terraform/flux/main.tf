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

provider "flux" {}

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

provider "github" {
  owner = data.sops_file.secrets.data["gh_owner"]
  token = data.sops_file.secrets.data["gh_token"]
}

variable "repository_name" {
  type        = string
  default     = "CloudHub-Cluster"
  description = "github repository name"
}

variable "repository_visibility" {
  type        = string
  default     = "private"
  description = "How visible is the github repo"
}

variable "branch" {
  type        = string
  default     = "main"
  description = "branch name"
}

variable "target_path" {
  type        = string
  default     = "cluster/production"
  description = "flux sync target path"
}

# SSH
locals {
  known_hosts = "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
}

resource "tls_private_key" "main" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

# Flux
data "flux_install" "main" {
  target_path = var.target_path
}

data "flux_sync" "main" {
  target_path = var.target_path
  url         = "ssh://git@github.com/${data.sops_file.secrets.data["gh_owner"]}/${var.repository_name}.git"
  branch      = var.branch
}

# Kubernetes
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

data "kubectl_file_documents" "install" {
  content = data.flux_install.main.content
}

data "kubectl_file_documents" "sync" {
  content = data.flux_sync.main.content
}

locals {
  install = [for v in data.kubectl_file_documents.install.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
  sync = [for v in data.kubectl_file_documents.sync.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
}

resource "kubectl_manifest" "install" {
  for_each   = { for v in local.install : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubernetes_namespace.flux_system]
  yaml_body  = each.value
}

resource "kubectl_manifest" "sync" {
  for_each   = { for v in local.sync : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubernetes_namespace.flux_system]
  yaml_body  = each.value
}

resource "kubernetes_secret" "main" {
  depends_on = [kubectl_manifest.install]

  metadata {
    name      = data.flux_sync.main.secret
    namespace = data.flux_sync.main.namespace
  }

  data = {
    identity       = tls_private_key.main.private_key_pem
    "identity.pub" = tls_private_key.main.public_key_pem
    known_hosts    = local.known_hosts
  }
}

# GitHub
data "github_repository" "main" {
  name = var.repository_name
}

data "github_branch" "main" {
  repository = data.github_repository.main.name
  branch     = var.branch
}

resource "github_repository_deploy_key" "main" {
  title      = "flux-production"
  repository = data.github_repository.main.name
  key        = tls_private_key.main.public_key_openssh
  read_only  = true
}

resource "github_repository_file" "install" {
  repository = data.github_repository.main.name
  file       = data.flux_install.main.path
  content    = data.flux_install.main.content
  branch     = var.branch
}

resource "github_repository_file" "sync" {
  repository = data.github_repository.main.name
  file       = data.flux_sync.main.path
  content    = data.flux_sync.main.content
  branch     = var.branch
}

resource "github_repository_file" "kustomize" {
  repository = data.github_repository.main.name
  file       = data.flux_sync.main.kustomize_path
  content    = data.flux_sync.main.kustomize_content
  branch     = var.branch
}
