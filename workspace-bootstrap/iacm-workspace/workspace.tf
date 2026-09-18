variable "repository" { type = string }
variable "repository_connector" { type = string }
variable "repository_path" { type = string }
variable "repository_branch" { type = string }
variable "repository_sha" {
  description = "Optional immutable revision for both code and tfvars; takes precedence over repository_branch."
  type        = string
  default     = ""
  nullable    = false
  validation {
    condition     = var.repository_sha == "" || can(regex("^[a-f0-9]{40}$", var.repository_sha))
    error_message = "Use an empty string or a full 40-character Git commit SHA."
  }
}
variable "provisioner_version" { type = string }
variable "workspace_secret_ref" {
  type = string
  validation {
    condition     = can(regex("^((account|org)\\.)?[A-Za-z_][A-Za-z0-9_$]{0,127}$", var.workspace_secret_ref))
    error_message = "Use a Harness secret reference, not a token."
  }
}
variable "terraform_variables" {
  type    = list(object({ key = string, value = string, value_type = string }))
  default = []
  validation {
    condition     = alltrue([for v in var.terraform_variables : v.key != "harness_account_id"])
    error_message = "harness_account_id is supplied by the pipeline."
  }
}
variable "terraform_variable_file" {
  description = "Optional repository-relative tfvars file in the workspace code repository."
  type        = string
  default     = ""
  nullable    = false
  validation {
    condition     = var.terraform_variable_file == "" || can(regex("^[A-Za-z0-9_-]+(/[A-Za-z0-9_-]+)*[.]tfvars([.]json)?$", var.terraform_variable_file))
    error_message = "Use a repository-relative .tfvars or .tfvars.json path without traversal or spaces."
  }
}

variable "environment_variables" {
  type    = list(object({ key = string, value = string, value_type = string }))
  default = []
  validation {
    condition     = alltrue([for v in var.environment_variables : !contains(["HARNESS_ACCOUNT_ID", "HARNESS_ENDPOINT", "HARNESS_PLATFORM_API_KEY"], v.key)])
    error_message = "Standard Harness environment variables are supplied by the pipeline."
  }
}

module "hpa_workspace" {
  source                  = "../modules/terraform-harness-iacm-workspace"
  workspace_name          = local.workspace_identifier
  workspace_identifier    = local.workspace_identifier
  workspace_description   = "Workspace created by the Configure Workspace stage template; grouped by tag."
  workspace_tags          = ["managed-by:idp-service-request", "group:${var.cluster_identifier}"]
  org_id                  = var.org_id
  project_id              = var.project_id
  cost_estimation_enabled = false
  provisioner_type        = "opentofu"
  provisioner_version     = var.provisioner_version
  repository              = var.repository
  repository_connector    = var.repository_connector
  repository_path         = var.repository_path
  repository_branch       = var.repository_sha == "" ? var.repository_branch : null
  repository_sha          = var.repository_sha == "" ? null : var.repository_sha
  terraform_variable_files = var.terraform_variable_file == "" ? [] : [{
    repository           = var.repository
    repository_connector = var.repository_connector
    repository_path      = var.terraform_variable_file
    repository_branch    = var.repository_sha == "" ? var.repository_branch : ""
    repository_commit    = ""
    repository_sha       = var.repository_sha
  }]
  terraform_variables = concat(var.terraform_variables, [
    { key = "harness_account_id", value = var.account_id, value_type = "string" }
  ])
  environment_variables = concat(var.environment_variables, [
    { key = "HARNESS_ACCOUNT_ID", value = var.account_id, value_type = "string" },
    { key = "HARNESS_ENDPOINT", value = var.endpoint, value_type = "string" },
    { key = "HARNESS_PLATFORM_API_KEY", value = var.workspace_secret_ref, value_type = "secret" }
  ])
}
