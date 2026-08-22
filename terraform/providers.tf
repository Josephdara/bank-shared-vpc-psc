# No default project is set: every resource names its project explicitly, since
# this configuration spans four projects (host, service A/B, partner).
provider "google" {
  region = var.region
}
