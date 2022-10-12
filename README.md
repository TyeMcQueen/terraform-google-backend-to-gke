# terraform-google-backend-to-gke

A Terraform module for easily building a Backend Service to a Workload
running in one or more GKE clusters.  Mostly meant to be used by the
[terraform-google-ingress-to-gke](
https://github.com/TyeMcQueen/terraform-google-ingress-to-gke) module
but can be useful on its own.


## Contents

* [Simplest Example](#simplest-example)
* [Multi-Region Example](#multi-region-example)
* [Output Values](#output-values)
* [Generic Options](#generic-options)
* [Backend Service](#backend-service)
* [Health Check](#health-check)
* [Limitations](#limitations)
* [Input Variables](#input-variables)


## Simplest Example

First, let's see how simple this module can be to use.  This invocation
of the module creates a Backend Service for a Kubernetes Workload running in
a GKE Cluster (via zonal Network Endpoint Groups), including generating a
generic Health Check.

    module "my-backend" {
      source            = (
        "github.com/TyeMcQueen/terraform-google-backend-to-gke" )
      cluster-objects   = [ google_container_cluster.my-gke.id ]
      neg-name          = "my-svc"
    }

Before you can `apply` such an invocation, you need to deploy your Workload
to the referenced cluster and it must include a Service object with an
annotation similar to:

    cloud.google.com/neg: '{"exposed_ports": {"80": {"name": "my-svc"}}}'

This step creates the Network Endpoint Groups (one per Compute Zone) that
route requests to any healthy instances of your Workload.  The "name" in
the annotation must match the `neg-name` you pass to this module.


## Multi-Region Example

Here is an example that configures a Backend Service that can be used
for multi-region ingress to your Workload running in multiple GKE
clusters (3 regional clusters in this case).

    module "my-ingress" {
      source            = (
        "github.com/TyeMcQueen/terraform-google-ingress-to-gke" )
      clusters          = {
      # Location           GKE Cluster Name
        us-central1     = "my-gke-usc1-prd",
        europe-west1    = "my-gke-euw1-prd",
        asia-east1      = "my-gke-ape1-prd",
      }
      neg-name          = "my-svc"
    }

You can use `clusters` and/or `cluster-objects` to specifies your GKE
Clusters.


## Output Values

The resource records for anything created by this module and some other
data are available as output values.

`module.NAME.backend` will be the resource record for the created Backend
Service.  You can use `module.NAME.backend.id` to reference this Backend
when creating other resources.

`module.NAME.health[0]` will be the resource record for the Health Check
if the module created one.

`module.NAME.negs` will be a map from each Compute Zone name to the resource
record for a zonal NEG (that was created by the GKE Ingress controller).

These are declared in [outputs.tf](/outputs.tf).


## Generic Options

See [inputs](#input-variables) or [variables.tf](variables.tf) for more
information about the generic `name-prefix`, `project`, and `description`
inputs.


## Backend Service

This module always creates one Backend Service.  You must set `neg-name`
to the `name` included in an annotation on your Kubernetes Service object
like:

    cloud.google.com/neg: '{"exposed_ports": {"80": {"name": "my-svc"}}}'

And you must list one or more GKE clusters that you have already
deployed such a Workload to.  You can list GKE cluster resource records
in `cluster-objects`.  You can put `location-name = "cluster-name"` pairs
into the `clusters` map.  You can even list some clusters in the former
and some in the latter.

You can set `lb-scheme = "EXTERNAL_MANAGED"` to use "modern" Global L7
HTTP(S) Load Balancing.

`log-sample-rate` defaults to 1.0 which logs all requests for your Backend.
You can set it to 0.0 to disable all request logging.  Or you can set it to
a value between 0.0 and 1.0 to log a sampling of requests.

You can also set `max-rps-per` to specify a different maximum rate of
requests (per second, per pod) that you want load balancing to adhere to.
But exceeding this rate simply causes requests to be rejected; it does not
impact how your Workload is scaled up.  It also does not adapt when the
average latency of responses changes.  So it is better to set this value
too high rather than too low.  It only functions as a worst-case rate limit
that may help to prevent some overload scenarios but using load shedding is
usually a better approach.


## Health Check

By default, this module creates a generic Health Check for the Backend
Service to use.  But you can instead reference a Health Check that you
created elsewhere via `health-ref`.

The generated Health Check will automatically determine which port number to
use.  The requests will use a User-Agent name that starts with "GoogleHC/",
so if you have your Workload detect this and then respond with health status,
then you don't have to have the Health Check and your Workload agree on a
specific URL to use.  But you can specify the URL path to use in
`health-path`.

See [inputs](#inputs) or [variables.tf](variables.tf) for more information
about the other Health Check options: `health-interval-secs`,
`health-timeout-secs`, `unhealthy-threshold`, and `healthy-threshold`.
If you need more customization that those provide, then you can simply
create your own Health Check and use `health-ref`.


## Limitations

* [Google Providers](#google-providers)
* [Error Handling](/docs/Limitations.md#error-handling)
* [Handling Cluster Migration](#handling-cluster-migration)

You should also be aware of types of changes that require special care as
documented in the other module's limitations: [Deletions](
https://github.com/TyeMcQueen/terraform-google-ingress-to-gke/blob/main/Limitations.md#deletions).

### Google Providers

This module uses the `google-beta` provider and allows the user to control
which version (via standard Terraform features for such).  We would like
to allow the user to pick between using the `google` and the `google-beta`
provider, but Terraform does not allow such flexibility with provider
usage in modules at this time.

You must use at least Terraform v0.13 as the module uses some features
that were not available in earlier versions.

You must use at least v4.22 of the `google-beta` provider.

### Handling Cluster Migration

The GKE automation that turns the Service Annotation into a Network Endpoint
Group (NEG) in each Compute Zone used by the GKE Cluster has one edge case
that can cause problems if you move your Workload to a new Cluster in the
same Compute Region or Zone.

The Created NEGs contain a reference to the creating Cluster.  When the
Workload is removed from a Cluster, the NEGs will not be destroyed
if the Backend Service created by this module still references them.  If
you then deploy the Workload to the new Cluster, the attempt to create
new NEGs will conflict with these lingering old NEGs.

So to migrate a Workload to a new Cluster that overlaps Zones, you must:

1. Either delete the Backend Service (such as by commenting out your
    invocation of this module) or just remove the particular NEGs from the
    Backend Service (by removing the original Cluster from `clusters` or
    `cluster-objects`).

2. `apply` the above change.

3. Remove the Workload from the old Cluster (or remove the Annotation).  Note
    that it is also okay to do this step first.

4. Verify that the NEGs have been garbage collected.

5. Deploy your Workload (with Service Annotation) to the new Cluster.

6. Add the new cluster to `clusters` or `cluster-objects` or uncomment the
    invocation of this module.

7. `apply` the above change.

If you have the Workload in another Cluster already, then this migration can
happen with no service interruption.


## Input Variables

* [cluster-objects](/variables.tf#L40)
* [clusters](/variables.tf#L27)
* [description](/variables.tf#L79)
* [health-interval-secs](/variables.tf#L162)
* [health-path](/variables.tf#L153)
* [health-ref](/variables.tf#L138)
* [health-timeout-secs](/variables.tf#L171)
* [healthy-threshold](/variables.tf#L190)
* [lb-scheme](/variables.tf#L92)
* [log-sample-rate](/variables.tf#L107)
* [max-rps-per](/variables.tf#L118)
* [name-prefix](/variables.tf#L56)
* [neg-name](/variables.tf#L5)
* [project](/variables.tf#L67)
* [unhealthy-threshold](/variables.tf#L180)
