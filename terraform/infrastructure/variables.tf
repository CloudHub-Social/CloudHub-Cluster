variable "pm_api_url" {
  description = "Proxmox API URL"
  type        = string
  sensitive = true
}

variable "pm_user" {
  description = "Proxmox User"
  type        = string
  sensitive = false
}

variable "pm_password" {
  description = "Proxmox Password"
  type        = string
  sensitive = true
}

variable "pm_host" {
  description = "Proxmox Host"
  type        = string
  sensitive = false
}
