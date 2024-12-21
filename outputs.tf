output "app_url" {
  value = "https://${var.custom_domain}"
}

output "cloudflare_project_domain" {
  value = "${cloudflare_pages_project.project.name}.pages.dev"
}
