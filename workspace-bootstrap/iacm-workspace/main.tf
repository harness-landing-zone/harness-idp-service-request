terraform {
  required_version = ">= 1.9.0"
  required_providers {
    harness = { source = "harness/harness", version = "= 0.45.5" }
  }
}

variable "account_id" { type = string }
variable "org_id" { type = string }
variable "project_id" { type = string }
variable "endpoint" { type = string }
variable "cluster_identifier" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,99}$", var.cluster_identifier))
    error_message = "Use a stable cluster key: lowercase letters, digits and underscores, starting with a letter, maximum 100 characters."
  }
}

variable "workspace_identifier" {
  description = "Explicit workspace ID. Empty falls back to workspace_<cluster_identifier>."
  type        = string
  default     = ""
  nullable    = false
  validation {
    condition     = var.workspace_identifier == "" || can(regex("^[A-Za-z_][A-Za-z0-9_]{0,127}$", var.workspace_identifier))
    error_message = "Use a stable workspace ID of up to 128 letters, digits or underscores, starting with a letter or underscore."
  }
}

provider "harness" {
  account_id = var.account_id
  endpoint   = var.endpoint
}

locals {
  workspace_identifier = var.workspace_identifier != "" ? var.workspace_identifier : "workspace_${var.cluster_identifier}"
}

data "harness_platform_workspaces" "existing" {
  org_id      = var.org_id
  project_id  = var.project_id
  search_term = local.workspace_identifier
}

output "workspace_identifier" {
  value = local.workspace_identifier
}
output "workspace_exists" {
  value = contains(data.harness_platform_workspaces.existing.identifiers, local.workspace_identifier)
}

output "workspace_import_id" {
  value = contains(data.harness_platform_workspaces.existing.identifiers, local.workspace_identifier) ? "${var.org_id}/${var.project_id}/${local.workspace_identifier}" : ""
}
