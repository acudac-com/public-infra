variable "name" {
  type        = string
  description = "The name of the Spanner instance. This is used to identify the instance within the project."
}
variable "config" {
  type        = string
  description = "The name of the instance's configuration (similar but not quite the same as a region) which defines the geographic placement and replication of your databases in this instance. It determines where your data is stored. Values are typically of the form 'regional-europe-west1' , 'us-central' etc."
}
variable "processing_units" {
  type        = number
  description = "The number of processing units allocated to this instance, e.g. 100, 200, etc."
}
variable "edition" {
  type        = string
  description = "The optional edition selected for this instance. Different editions provide different capabilities at different price points. Possible values: STANDARD (default), ENTERPRISE, ENTERPRISE_PLUS"
  default     = "STANDARD"
}

resource "google_spanner_instance" "main" {
  name                         = var.name
  config                       = var.config
  display_name                 = var.name
  processing_units             = var.processing_units
  edition                      = var.edition
  default_backup_schedule_type = "NONE"
}

resource "google_spanner_database" "environments" {
  deletion_protection      = true
  for_each                 = toset(["dev", "staging", "prod"])
  instance                 = google_spanner_instance.main.name
  name                     = each.key
  version_retention_period = "1h"
  database_dialect         = "GOOGLE_STANDARD_SQL"
}

resource "google_spanner_backup_schedule" "prod_daily_full" {
  instance           = google_spanner_instance.main.name
  database           = google_spanner_database.environments["prod"].name
  name               = "daily-full"
  retention_duration = "1209600s" // 14 days
  spec {
    cron_spec {
      text = "0 0 * * *" // Every day at midnight
    }
  }
  full_backup_spec {
  }
}

