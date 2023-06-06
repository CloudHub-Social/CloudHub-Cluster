variable "cluster_name" {
  description = "A name to provide for the Talos cluster"
  type        = string
  default = "talos-proxmox-cluster"
}

variable "cluster_endpoint" {
  description = "The endpoint for the Talos cluster"
  type        = string
  default = "https://10.0.41.10:6443"
}

variable "node_data" {
  description = "A map of node data"
  type = object({
    controlplanes = map(object({
      install_disk = string
      hostname     = optional(string)
    }))
    workers = map(object({
      install_disk = string
      hostname     = optional(string)
    }))
  })
  default = {
    controlplanes = {
      "10.0.41.20" = {
        install_disk = "/dev/sda"
        hostname  = "talos-control-1"
      },
      "10.0.41.21" = {
        install_disk = "/dev/sda"
        hostname  = "talos-control-2"
      },
      "10.0.41.22" = {
        install_disk = "/dev/sda"
        hostname  = "talos-control-3"
      }
    }
    workers = {
      "10.0.41.30" = {
        install_disk = "/dev/sda"
        hostname     = "talos-worker-1"
      },
      "10.0.41.31" = {
        install_disk = "/dev/sda"
        hostname     = "talos-worker-2"
      },
      "10.0.41.32" = {
        install_disk = "/dev/sda"
        hostname     = "talos-worker-3"
      }
    }
  }
}