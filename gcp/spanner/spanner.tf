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
variable "dev_dbs" {
  type        = list(string)
  description = "The list of databases to create for development. These databases won't be backed up."
}
variable "prod_dbs" {
  type        = list(string)
  description = "The list of databases to create for production. These databases will be backed up."
}

resource "google_spanner_instance" "main" {
  name                         = var.name
  config                       = var.config
  display_name                 = var.name
  processing_units             = var.processing_units
  edition                      = var.edition
  default_backup_schedule_type = "NONE"
}

resource "google_spanner_database" "dev" {
  for_each                 = toset(var.dev_dbs)
  deletion_protection      = false
  instance                 = google_spanner_instance.main.name
  name                     = each.key
  version_retention_period = "1h"
  database_dialect         = "GOOGLE_STANDARD_SQL"
}

resource "google_spanner_database" "prod" {
  for_each                 = toset(var.prod_dbs)
  deletion_protection      = false
  instance                 = google_spanner_instance.main.name
  name                     = each.key
  version_retention_period = "1h"
  database_dialect         = "GOOGLE_STANDARD_SQL"
}

resource "google_spanner_backup_schedule" "prod" {
  for_each           = toset(var.prod_dbs)
  instance           = google_spanner_instance.main.name
  database           = google_spanner_database.prod[each.key].name
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

