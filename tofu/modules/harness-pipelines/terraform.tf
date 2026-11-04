terraform {
  required_version = ">= 1.9.0"
  required_providers {
    local   = { source = "hashicorp/local", version = ">= 2.5" }
    harness = { source = "harness/harness", version = ">= 0.45" }
  }
}
