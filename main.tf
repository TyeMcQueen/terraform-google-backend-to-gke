
data "google_client_config" "default" {
}

terraform {
  required_version = ">= 0.13"
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = ">= 4.22"
    }
  }
}

locals {
  prefix = var.name-prefix == "" ? "${var.neg-name}-" : var.name-prefix

  # Try to give a hint what failed if local.project ends up empty:
  project = ( "" != var.project ? var.project :
    [ for p in [ data.google_client_config.default.project ] :
        try( "" != p, false ) ? p
        : "google_client_config.default does not define '.project'" ][0] )
}

# Look up the GKE Cluster(s) created elsewhere:
data "google_container_cluster" "k" {
  for_each  = var.clusters
  name      = each.value
  location  = each.key
}

# Look up all of the zones where NEGs will be allocated:
locals {
  zones = toset( flatten( [
    [ for region, name in var.clusters :
      [ for z in [ data.google_container_cluster.k[region].node_locations ] :
        try( 0 < length(z), false ) ? z
        : toset(["GKE Cluster ${name} in ${region} not found"]) ][0] ],
    [ for obj in var.cluster-objects : obj.node_locations ],
  ] ) )
}

# Look up the NEGs created by a GKE annotation:
data "google_compute_network_endpoint_group" "neg" {
  for_each  = local.zones
  name      = var.neg-name
  zone      = each.value
}

locals {
  hc-parts = split( "/", var.health-ref )
  hc-proj = ( var.health-ref == "" ? ""
    : 2 == length(local.hc-parts) ? local.hc-parts[0]
    : 1 == length(local.hc-parts) ? local.project : "" )
  hc-title = ( var.health-ref == "" ? ""
    : 2 == length(local.hc-parts) ? local.hc-parts[1]
    : 1 == length(local.hc-parts) ? local.hc-parts[0] : "" )
}

# Load a health check created elsewhere:
data "google_compute_health_check" "h" {
  count     = local.hc-title == "" ? 0 : 1
  name      = local.hc-title
  project   = local.hc-proj
}

# OR Create a generic health check:
resource "google_compute_health_check" "h" {
  count     = var.health-ref == "" ? 1 : 0
  name      = "${local.prefix}health"

  project       = local.project
  description   = var.description
# labels        = var.labels

  check_interval_sec    = var.health-interval-secs
  timeout_sec           = var.health-timeout-secs
  unhealthy_threshold   = var.unhealthy-threshold
  healthy_threshold     = var.healthy-threshold

  log_config { enable = true }

  http_health_check {
    request_path        = var.health-path
    port_specification  = "USE_SERVING_PORT"
  }
}

locals {
  hc-id = ( var.health-ref == ""
    ? google_compute_health_check.h[0].id
    : [ for id in [ data.google_compute_health_check.h[0].id ] :
        try( id != "", false ) ? id
        : "Health Check ${local.hc-proj}/${local.hc-title} not found" ][0] )

  neg-ids = ( [
    for z in local.zones : [
      for id in [ data.google_compute_network_endpoint_group.neg[z].id ] :
        try( 0 < length(id), false ) ? id
        : "NEG ${var.neg-name} in ${z} not found" ][0] ] )
}

# Create a backend that routes to all of the NEGs:
resource "google_compute_backend_service" "b" {
  name      = "${local.prefix}backend"

  project       = local.project
  description   = var.description
# labels        = var.labels

  health_checks         = [ local.hc-id ]
  load_balancing_scheme = var.lb-scheme
  log_config {
    enable      = 0.0 < var.log-sample-rate
    sample_rate = var.log-sample-rate
  }

  dynamic "backend" {
    for_each = local.neg-ids
    content {
      balancing_mode        = "RATE"
      max_rate_per_endpoint = var.max-rps-per
      # Terraform defaults to 0.8 which doesn't make sense for "RATE" w/ NEGs:
      max_utilization       = 0.0
      group                 = backend.value
    }
  }
}

