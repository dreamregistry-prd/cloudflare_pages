output "app_url" {
  value = "https://${var.domain_name}"
}

output "cloudflare_project_domain" {
  value = "${cloudflare_pages_project.project.name}.pages.dev"
}
