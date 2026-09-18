terraform {
  required_version = ">= 1.9.0"
  required_providers {
    harness = { source = "harness/harness", version = "~> 0.45" }
    local   = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

# Native provider authentication: HARNESS_ACCOUNT_ID, HARNESS_PLATFORM_API_KEY
# and optionally HARNESS_ENDPOINT.
provider "harness" {}
