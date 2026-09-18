variable "harness_account_id" {
  description = "[Optional] Set on every workspace by the workspace bootstrap template. Not used here: the provider reads HARNESS_ACCOUNT_ID. Declared so the workspace's variable is accepted."
  type        = string
  default     = null
}

variable "organization_identifier" {
  description = "Existing Harness organization that owns the project."
  type        = string
}

variable "project_identifier" {
  description = "Existing Harness project that will own the Services."
  type        = string
}

##############################################################################
# Path resolution for this example root. The module itself only takes
# directories; how they are laid out is the caller's choice.
##############################################################################

variable "configs_relative_path" {
  description = "[Optional] Relative path from this folder to the configs root. Used when configs_root is not set."
  type        = string
  default     = "configs"
}

variable "configs_root" {
  description = "[Optional] Absolute path to the configs root. Overrides configs_relative_path when set."
  type        = string
  default     = null
}

variable "organization_folder" {
  description = "[Optional] Folder name of the organization under organizations/. Defaults to organization_identifier."
  type        = string
  default     = null
}

variable "project_key" {
  description = "[Optional] Folder name of the project under projects/. Defaults to project_identifier."
  type        = string
  default     = null
}

##############################################################################
# Requests, passed straight to the module. See the module for the shape.
##############################################################################

variable "services" {
  description = "Requested Services grouped by type, then keyed by identifier. Validated by the module."
  type        = any
  default     = {}
}

variable "write_files" {
  description = "Write config files to disk. True here so a local run produces the files; a read-only caller leaves the modules' default of false."
  type        = bool
  default     = true
}

variable "verify_environments" {
  description = "Look up each target environment in Harness during plan. Off by default because the provider's environment data source crashes when the environment is missing; see the module variable."
  type        = bool
  default     = false
}
