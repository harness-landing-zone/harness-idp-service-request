terraform {
  required_version = ">= 1.9.0"
  required_providers {
    harness = { source = "harness/harness", version = ">= 0.45" }
    local   = { source = "hashicorp/local", version = ">= 2.5" }
  }
}

# No provider block: the caller configures the Harness provider.
