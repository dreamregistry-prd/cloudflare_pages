terraform {
  #  backend "s3" {}

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~>4.2"
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

resource "cloudflare_pages_domain" "custom_domain" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.project.name
  domain       = var.domain_name
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

resource "terraform_data" "deploy" {
  triggers_replace = [
    data.archive_file.public_folder.output_base64sha256,
    data.archive_file.functions_folder.output_base64sha256,
    var.kv_namespaces,
    var.dream_env,
  ]

  provisioner "local-exec" {
    command = "cd ${var.dream_project_dir} && pnpm dlx wrangler pages publish --project-name ${cloudflare_pages_project.project.name} public"
  }

  depends_on = [
    cloudflare_pages_project.project
  ]
}