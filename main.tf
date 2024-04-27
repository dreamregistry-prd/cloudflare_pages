terraform {
  backend "s3" {}

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~>4.2"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.61"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.4"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~>2.3"
    }
  }
}

provider "cloudflare" {}
provider "random" {}
provider "archive" {}

resource "random_pet" "project_name" {
  length = 3
  prefix = var.cloudflare_project_name_prefix
}

resource "cloudflare_pages_project" "project" {
  account_id        = var.cloudflare_account_id
  name              = random_pet.project_name.id
  production_branch = "main"
  deployment_configs {
    preview {}
    production {
      environment_variables = var.dream_env
      kv_namespaces         = {
        for kv_namespace in toset(var.kv_namespaces) :
        kv_namespace => cloudflare_workers_kv_namespace.cache[kv_namespace].id
      }
    }
  }
}

data "aws_route53_zone" "domain" {
  name = var.root_domain
}

resource "aws_route53_record" "domain" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "${var.domain_name_prefix}.${data.aws_route53_zone.domain.name}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${cloudflare_pages_project.project.name}.pages.dev"]
}

resource "cloudflare_pages_domain" "custom_domain" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.project.name
  domain       = aws_route53_record.domain.name
}


resource "random_pet" "kv_namespace" {
  for_each = toset(var.kv_namespaces)
  length   = 3
  prefix   = var.kv_namespace_prefix
}

resource "cloudflare_workers_kv_namespace" "cache" {
  for_each   = toset(var.kv_namespaces)
  account_id = var.cloudflare_account_id
  title      = random_pet.kv_namespace[each.key].id
}

data "archive_file" "public_folder" {
  type        = "zip"
  source_dir  = "${var.dream_project_dir}/public"
  output_path = ".cloudflare_pages_public.zip"
}

data "archive_file" "functions_folder" {
  type        = "zip"
  source_dir  = "${var.dream_project_dir}/functions"
  output_path = ".cloudflare_pages_functions.zip"
}

data "archive_file" "build_folder" {
  output_path = ".cloudflare_pages_build.zip"
  type        = "zip"
  source_dir = "${var.dream_project_dir}/build"
}

resource "terraform_data" "deploy" {
  triggers_replace = [
    data.archive_file.public_folder.output_base64sha256,
    data.archive_file.functions_folder.output_base64sha256,
    data.archive_file.build_folder.output_base64sha256,
    var.kv_namespaces,
    var.dream_env,
  ]

  provisioner "local-exec" {
    command = "cd ${var.dream_project_dir} && npm run ${var.build_script} && npx wrangler pages deploy --project-name ${cloudflare_pages_project.project.name}"
  }

  depends_on = [
    cloudflare_pages_project.project
  ]
}