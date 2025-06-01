variable "org_id" {
  type        = string
  description = "The organization ID for the GCP organization, e.g. 123456789"
}
variable "host_project" {
  type        = string
  description = "The id of the organization's host project. This will be where your docker images, dns zones, ssl certificates, spanner instance and loadbalancer will live."
}
variable "billing_account" {
  type        = string
  description = "The billing account ID to use for the host project, e.g. QW2GW3-123456-HTRU74H"
}
variable "tfstate_bucket" {
  type        = string
  description = "The name of the GCS bucket to store Terraform state files, e.g. tfstate.example.com. This bucket is created in the host project."
}
variable "tfstate_bucket_location" {
  type        = string
  description = "The optional location of the GCS bucket for Terraform state files. Default is europe-west1"
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
  name            = var.host_project
  project_id      = var.host_project
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

resource "google_storage_bucket" "tfstate" {
  name                     = var.tfstate_bucket
  location                 = var.tfstate_bucket_location
  public_access_prevention = "enforced"
  versioning {
    enabled = true
  }
  uniform_bucket_level_access = false

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age                = 0
      num_newer_versions = 10
    }
  }
}
