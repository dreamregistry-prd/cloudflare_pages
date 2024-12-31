variable "dream_env" {
  description = "dream app environment variables to set"
  type        = any
  sensitive   = false
  default     = {}
}

variable "dream_project_dir" {
  description = "root directory of the project sources"
  type        = string
}

variable "d1_databases" {
  description = "d1 database name"
  type        = set(string)
  default     = []
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

variable "custom_domain" {
  description = "custom domain name"
  type        = string
}

variable "build_script" {
  description = "npm script to run to build the project"
  default     = "build"
}

variable "app_folder" {
  description = "folder where the app is stored"
  default     = "app"
}
