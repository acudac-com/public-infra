variable "name" {
  type        = string
  description = "Name of the product e.g. graziemille."
}
variable "org_project" {
  type        = string
  description = "The organisation's main project where its spanner instance and docker images are managed."
}
variable "region" {
  type        = string
  description = "The region to deploy the product's buckets and docker registry."
}
variable "bucket_domain" {
  type        = string
  description = "The bucket domain to use for each environment's bucket."
}
variable "spanner_instance" {
  type        = string
  description = "Name of the spanner instance this product's environments can store their data in."
}
variable "environment_projects" {
  type        = list(string)
  description = "The ids of the google projects into which this product is deployed."
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
  for_each     = toset(var.environment_projects)
  project      = each.key
  account_id   = "${var.name}-main"
  display_name = "${var.name}-main"
}

resource "google_spanner_database_iam_member" "fine_grained" {
  for_each = toset(var.environment_projects)
  project  = var.org_project
  instance = var.spanner_instance
  database = each.key
  role     = "roles/spanner.fineGrainedAccessUser"
  member   = "serviceAccount:${google_service_account.main[each.key].email}"
}

resource "google_spanner_database_iam_member" "database_role" {
  for_each = toset(var.environment_projects)
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
  for_each = toset(var.environment_projects)
  name     = "${var.name}.${each.key}.${var.bucket_domain}"
  project  = each.key
  location = var.region

  soft_delete_policy {
    retention_duration_seconds = 604800 // 7 days
  }
  versioning {
    enabled = true
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
  for_each = toset(var.environment_projects)
  bucket   = google_storage_bucket.main[each.key].name
  role     = "roles/storage.admin"
  member   = "serviceAccount:${google_service_account.main[each.key].email}"
}


