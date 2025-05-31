variable "domain" {
  type        = string
  description = "The domain to create an ssl certificate for"
}
variable "maps" {
  type        = list(string)
  description = "The ids of the certificate maps to add certificate map entries to"
}

resource "google_certificate_manager_dns_authorization" "main" {
  name     = replace(var.domain, ".", "-")
  location = "global"
  domain   = var.domain
}

resource "google_dns_record_set" "main" {
  name         = google_certificate_manager_dns_authorization.main.dns_resource_record.0.name
  type         = google_certificate_manager_dns_authorization.main.dns_resource_record.0.type
  ttl          = 300
  managed_zone = replace(var.domain, ".", "-")
  rrdatas      = [google_certificate_manager_dns_authorization.main.dns_resource_record.0.data]
}

resource "google_certificate_manager_certificate" "main" {
  name  = replace(var.domain, ".", "-")
  scope = "DEFAULT"
  managed {
    domains = [
      var.domain,
      "*.${var.domain}",
    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.main.id,
    ]
  }
}

resource "google_certificate_manager_certificate_map_entry" "root" {
  for_each     = toset(var.maps)
  name         = replace(var.domain, ".", "-")
  map          = each.key
  certificates = [google_certificate_manager_certificate.main.id]
  hostname     = var.domain
}

resource "google_certificate_manager_certificate_map_entry" "wildcard" {
  for_each     = toset(var.maps)
  name         = "wildcard-${replace(var.domain, ".", "-")}"
  map          = each.key
  certificates = [google_certificate_manager_certificate.main.id]
  hostname     = "*.${var.domain}"
}
