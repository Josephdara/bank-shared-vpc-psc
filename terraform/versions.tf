terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }

  # Remote state lives in the GCS bucket created by ../bootstrap.sh.
  # The bucket name is dynamic, so it is supplied at init time:
  #   terraform init -backend-config=backend.hcl
  backend "gcs" {}
}
