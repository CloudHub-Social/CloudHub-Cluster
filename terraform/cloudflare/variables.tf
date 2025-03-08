variable "cf_email" {
  description = "CloudFlare Email"
  type        = string
  sensitive = true
}

variable "cf_apikey" {
  description = "CloudFlare API Key"
  type        = string
  sensitive = true
}

variable "cf_domain" {
  description = "CloudFlare Domain"
  type        = string
  sensitive = true
}
