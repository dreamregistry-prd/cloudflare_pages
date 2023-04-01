output "app_url" {
  value = "https://${aws_route53_record.domain.name}"
}

output "cloudflare_project_domain" {
  value = "${cloudflare_pages_project.project.name}.pages.dev"
}
