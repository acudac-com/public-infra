variable "org_id" {
  type        = string
  description = "The organization ID for the GCP organization, e.g. 123456789"
}
variable "org_project" {
  type        = string
  description = "The id of the organization's project. This is the shared vpc host and where your docker images, dns zones, ssl certificates, spanner instance and loadbalancer will live."
}
variable "billing_account" {
  type        = string
  description = "The billing account ID to use for the host project, e.g. QW2GW3-123456-HTRU74H"
}
variable "buckets_domain" {
  type        = string
  description = "The domain to use for the bucket names, which will result in a git.{domain} and tfstate.{domain} bucket."
}
variable "buckets_location" {
  type        = string
  description = "The optional location of the tfstate and git GCS buckets. Default is europe-west1"
  default     = "europe-west1"
}

resource "google_organization_policy" "disabled" {
  for_each   = toset(["iam.disableServiceAccountKeyCreation"])
  org_id     = var.org_id
  constraint = each.key
  boolean_policy {
    enforced = false
  }
}

resource "google_project" "main" {
  name            = var.org_project
  project_id      = var.org_project
  org_id          = var.org_id
  billing_account = var.billing_account
}

resource "google_project_service" "main" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "cloudbilling.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
    "domains.googleapis.com",
    "certificatemanager.googleapis.com",
    "spanner.googleapis.com",
  ])
  project            = google_project.main.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_compute_shared_vpc_host_project" "main" {
  project = google_project.main.project_id
}

// All terraform state for the organisation.
resource "google_storage_bucket" "tfstate" {
  name                     = "tfstate.${var.buckets_domain}"
  location                 = var.buckets_location
  project                  = var.org_project
  public_access_prevention = "enforced"
  versioning {
    enabled = true
  }
  uniform_bucket_level_access = true

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age                = 30
      num_newer_versions = 10
    }
  }
}
