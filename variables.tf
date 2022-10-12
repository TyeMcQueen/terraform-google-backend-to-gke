

###--- Required inputs ---###

variable "neg-name" {
  description   = <<-EOD
    Required name assigned to the Network Endpoint Group you created via
    an annotation added to your Kubernetes Service resource.

    Example: neg-name = "api"
    would work with the following Service annotation:
      cloud.google.com/neg: '{"exposed_ports": {"80": {"name": "api"}}}'
  EOD
  type          = string

  validation {
    condition       = "" != var.neg-name
    error_message   = "Must not be \"\"."
  }
}


###--- Clusters ---###

# At least one of "clusters" and "cluster-objects" must not be empty.

variable "clusters" {
  description   = <<-EOD
    A map from GCP Compute Region (or Zone) name to GKE Cluster Name
    in that Region.  The cluster name can be "$${project-id}/$${name}"
    to use a cluster in a different GCP Project.  This and/or
    `cluster-objects` must not be empty.
    Example:
      clusters = { us-central1 = "gke-my-product-prd-usc1" }
  EOD
  type          = map(string)
  default       = {}
}

variable "cluster-objects" {
  description   = <<-EOD
    A list of google_container_cluster resource objects.  Usually, each
    is a reference to a resource or data declaration.  But all that is
    required is that each object have an appropriate value for
    `node_locations` (a list of Compute Zone names).
    Example: cluster-list = [
      google_container_cluster.usc, data.google_container_cluster.legacy ]
  EOD
  type          = list(object({node_locations=list(string)}))
  default       = []
}


###--- Generic Options ---###

variable "name-prefix" {
  description   = <<-EOD
    The prefix string to prepend to the `.name` of the GCP resources created
    by this module.  If left as "", then "$${neg-name}-" will be used.

    Example: name-prefix = "my-svc-"
  EOD
  type          = string
  default       = ""
}

variable "project" {
  description   = <<-EOD
    The ID of the GCP Project that most resources will be created in.
    Defaults to "" which uses the default project of the Google client
    configuration.

    Example: project = "my-gcp-project"
  EOD
  type          = string
  default       = ""
}

variable "description" {
  description   = <<-EOD
    An optional description to be used on every created resource.

    Example: description = "Created by Terraform module backend-to-gke"
  EOD
  type          = string
  default       = ""
}


###--- Backend options ---###

variable "lb-scheme" {
  description   = <<-EOD
    Defaults to "EXTERNAL" ["Classic" Global L7 HTTP(S) LB].  Can be set
    to "EXTERNAL_MANAGED" ["Modern" Global L7 HTTP(S) LB].
  EOD
  type          = string
  default       = "EXTERNAL"

  validation {
    condition       = (
      var.lb-scheme == "EXTERNAL" || var.lb-scheme == "EXTERNAL_MANAGED" )
    error_message   = "Must be \"EXTERNAL\" or \"EXTERNAL_MANAGED\"."
  }
}

variable "log-sample-rate" {
  description   = <<-EOD
    The fraction [0.0 .. 1.0] of requests to your Backend Service that should
    be logged.  Setting this to 0.0 will set `log_config.enabled = false`.

    Example: log-sample-rate = 0.01
  EOD
  type          = number
  default       = 1.0
}

variable "max-rps-per" {
  description   = <<-EOD
    The maximum requests-per-second that load balancing will send per
    endpoint (per pod); set as `max_rate_per_endpoint` in the created
    Backend Service.  Setting this value too low can cause problems (it
    will not cause more pods to be spun up but just cause requests to be
    rejected).  It is possible to use this as a rate limit that is one part
    of protecting your pods from excessive request volume, but doing this
    requires considerable care.  So err on the side of setting it too high
    rather than too low.

    Example: max-rps-per = 500
  EOD
  type          = number
  default       = 1000
}


###--- Health check options ---###

variable "health-ref" {
  description   = <<-EOD
    Either the name given to a Health Check resource in this project,
    "$${project-id}/$${name}" for a Health Check in a different project,
    just a full Health Check resource `.id`, or "" to have a generic
    Health Check created.

    Examples:
      health-ref = "api-hc"
      health-ref = google_compute_health_check.hc.id
  EOD
  type          = string
  default       = ""
}

variable "health-path" {
  description   = <<-EOD
    Path to use in created Health Check (only if `health-ref` left as "").
    Example: health-path = "/ready"
  EOD
  type          = string
  default       = "/"
}

variable "health-interval-secs" {
  description   = <<-EOD
    How long to wait between health checks, in seconds.
    Example: health-interval-sec = 10
  EOD
  type          = number
  default       = 5
}

variable "health-timeout-secs" {
  description   = <<-EOD
    How long to wait for a reply to a health check, in seconds.
    Example: health-timeout-sec = 10
  EOD
  type          = number
  default       = 5
}

variable "unhealthy-threshold" {
  description   = <<-EOD
    How many failed health checks before a Backend instance is considered
    unhealthy (thus no longer routing requests to it).
    Example: unhealthy-threshold = 1
  EOD
  type          = number
  default       = 2
}

variable "healthy-threshold" {
  description   = <<-EOD
    How many successful health checks to an unhealthy Backend instance
    are required before the Backend is considered healthy (thus again
    routing requests to it).

    Example: healthy-threshold = 1
  EOD
  type          = number
  default       = 2
}

