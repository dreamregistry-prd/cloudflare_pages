variable "dream_env" {
  description = "dream app environment variables to set"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "dream_project_dir" {
  description = "root directory of the project sources"
  type        = string
}

variable "kv_namespaces" {
  description = "list of kv namespaces binding variables to create"
  type        = list(string)
  default     = []
}

variable "kv_namespace_prefix" {
  description = "prefix to use for cloudflare kv namespaces names"
  type        = string
  default     = "app"
}

variable "cloudflare_account_id" {
  description = "cloudflare account id"
  type        = string
}

variable "cloudflare_project_name_prefix" {
  description = "cloudflare project name prefix"
  type        = string
  default     = "app"
}

variable "domain_name_prefix" {
  description = "cloudflare custom domain name"
  type        = string
}

variable "root_domain" {
  description = "root domain name"
  type        = string
}
