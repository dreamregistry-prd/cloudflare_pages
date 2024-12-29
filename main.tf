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

locals {
  non_secret_env_temp = {
    for k, v in var.dream_env : k => try(tostring(v), null)
  }
  non_secret_env = {
    for k, v in local.non_secret_env_temp : k => v if v != null && !startswith(k, "IAM_POLICY_")
  }
  secret_env_temp = {
    for k, v in var.dream_env : k => try(tostring(v.key), null)
  }
  secret_env = {
    for k, v in local.secret_env_temp : k => v if v != null
  }

}

resource "random_pet" "project_name" {
  length = 3
  prefix = var.cloudflare_project_name_prefix
}

data "aws_ssm_parameter" "secrets_env" {
  for_each = local.secret_env
  name     = each.value.key
  with_decryption = true
}

locals {
  decrypted_secret_env = {
    for k, v in data.aws_ssm_parameter.secrets_env : k => v.value
  }
  env = merge(local.non_secret_env, local.decrypted_secret_env)
}


resource "cloudflare_pages_project" "project" {
  account_id        = var.cloudflare_account_id
  name              = random_pet.project_name.id
  production_branch = "main"
  deployment_configs {
    preview {}
    production {
      environment_variables = local.env
      kv_namespaces = {
        for kv_namespace in toset(var.kv_namespaces) :
        kv_namespace => cloudflare_workers_kv_namespace.cache[kv_namespace].id
      }
    }
  }
}

data "cloudflare_zone" "domain" {
  name = var.custom_domain
}

resource "cloudflare_record" "custom_domain" {
  zone_id = data.cloudflare_zone.domain.id
  name    = "@"
  content = "${cloudflare_pages_project.project.name}.pages.dev"
  type    = "CNAME"
  proxied = true
}


resource "cloudflare_record" "custom_domain_www" {
  zone_id = data.cloudflare_zone.domain.id
  name    = "www"
  content = "${cloudflare_pages_project.project.name}.pages.dev"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_pages_domain" "custom_domain" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.project.name
  domain       = var.custom_domain
}

resource "cloudflare_pages_domain" "custom_domain_www" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.project.name
  domain       = "www.${var.custom_domain}"
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

data "archive_file" "app_folder" {
  output_path = ".cloudflare_pages_app.zip"
  type        = "zip"
  source_dir  = "${var.dream_project_dir}/${var.app_folder}"
}

resource "terraform_data" "deploy" {
  triggers_replace = [
    data.archive_file.public_folder.output_base64sha256,
    data.archive_file.functions_folder.output_base64sha256,
    data.archive_file.app_folder.output_base64sha256,
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
