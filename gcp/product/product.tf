variable "name" {
  type        = string
  description = "Name of the product e.g. graziemille."
}
variable "bucket_domain" {
  type        = string
  description = "The bucket domain to use for each environment's bucket."
}
variable "org_project" {
  type        = string
  description = "The organisation's main project where its spanner instance and docker images are managed."
}
variable "region" {
  type        = string
  description = "The region to deploy the product's buckets and docker registry."
}
variable "dev_project" {
  type        = string
  description = "The google project to use as the product's dev environment. A service account is created for the product in this project."
}
variable "staging_project" {
  type        = string
  description = "The google project to use as the product's staging environment. A service account is created for the product in this project."
}
variable "prod_project" {
  type        = string
  description = "The google project to use as the product's prod environment. A service account is created for the product in this project."
}
variable "spanner_instance" {
  type        = string
  description = "Name of the spanner instance this product's environments can store their data in."
}

locals {
  environments = {
    "dev" : var.dev_project
    "staging" : var.staging_project
    "prod" : var.prod_project
  }
}

resource "google_artifact_registry_repository" "main" {
  project       = var.org_project
  location      = var.region
  repository_id = var.name
  format        = "DOCKER"
  cleanup_policies {
    id     = "keep"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }
  cleanup_policies {
    id     = "delete"
    action = "DELETE"
    condition {
      older_than = "30d"
    }
  }
}

resource "google_service_account" "main" {
  for_each     = local.environments
  project      = each.value
  account_id   = var.name
  display_name = var.name
}

resource "google_spanner_database_iam_member" "fine_grained" {
  for_each = local.environments
  project  = var.org_project
  instance = var.spanner_instance
  database = each.key
  role     = "roles/spanner.fineGrainedAccessUser"
  member   = "serviceAccount:${google_service_account.main[each.key].email}"
}

resource "google_spanner_database_iam_member" "database_role" {
  for_each = local.environments
  project  = var.org_project
  instance = var.spanner_instance
  database = each.key
  role     = "roles/spanner.databaseRoleUser"
  condition {
    title      = "Fine grained role access"
    expression = "resource.type == \"spanner.googleapis.com/DatabaseRole\" && resource.name.endsWith(\"/${var.name}\")"
  }
  member = "serviceAccount:${google_service_account.main[each.key].email}"
}

resource "google_storage_bucket" "main" {
  for_each = local.environments
  name     = "${var.name}.${each.value}.${var.bucket_domain}"
  project  = each.value
  location = var.region

  soft_delete_policy {
    retention_duration_seconds = 604800 // 7 days
  }
  versioning {
    enabled = false
  }
  uniform_bucket_level_access = true

  // delete non-current objects older than 3 days
  lifecycle_rule {
    condition {
      age                = 3
      num_newer_versions = 1
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket_iam_member" "main" {
  for_each = local.environments
  bucket   = google_storage_bucket.main[each.key].name
  role     = "roles/storage.admin"
  member   = "serviceAccount:${google_service_account.main[each.key].email}"
}


