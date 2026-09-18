##############################################################################
# Scope. The caller owns the organization, project and environments; this
# module only uses them.
##############################################################################

variable "org_id" {
  description = "Harness organization identifier that owns the project."
  type        = string
}

variable "project_id" {
  description = "Harness project identifier that owns the environments."
  type        = string
}

variable "tags" {
  description = "[Optional] Tags added to every Infrastructure Definition."
  type        = map(string)
  default     = {}
}

##############################################################################
# Where infrastructure files live. The caller resolves paths.
##############################################################################

variable "infrastructures_dirs" {
  description = "Absolute directories holding infrastructure files as <environment>/<identifier>.yaml. Later directories win when the same relative path exists in more than one. A directory that does not exist yet is treated as empty."
  type        = list(string)

  validation {
    condition     = length(var.infrastructures_dirs) > 0
    error_message = "Give at least one infrastructures directory."
  }
}

variable "write_dir" {
  description = "[Optional] Directory new requests are written to. Defaults to the last entry of infrastructures_dirs."
  type        = string
  default     = null
}

variable "write_files" {
  description = "[Optional] Write infrastructure files to disk: a new request writes its render, an existing file keeps its own content. Leave false for a read-only caller."
  type        = bool
  default     = false
}

variable "templates_dir" {
  description = "[Optional] Directory of type folders, each holding infrastructure.tpl. Defaults to the templates folder shipped next to this module."
  type        = string
  default     = null
}

variable "verify_environments" {
  description = "[Optional] Look up every environment in Harness during plan. Off by default: with provider 0.45 the environment data source crashes the plugin (\"Plugin did not respond\") when the environment does not exist, which is a worse message than the API's own \"environment not found\" at apply time. Needs real credentials."
  type        = bool
  default     = false
}

##############################################################################
# Requests
##############################################################################

variable "infrastructures" {
  description = <<-EOT
    [Optional] Requested Infrastructure Definitions grouped by type, then by
    identifier, then by environment:
      infrastructures = { cloudrun = { orders_api = { dev = { connector_ref = "...", project = "...", region = "..." } } } }
    The group key is the type: it selects <type>/infrastructure.tpl. The
    identifier is normally the Service the target belongs to. Each environment
    entry holds the values that type's template reads, plus an optional name.
    Requests join the existing files found in infrastructures_dirs. The type is
    any because each type has its own shape.
  EOT
  type        = any
  default     = {}

  validation {
    condition = alltrue(flatten([for type, group in var.infrastructures : [
      for id, environments in group : [
        for environment, config in environments :
        can(regex("^[a-z][a-z0-9_]{0,62}$", id)) && can(regex("^[A-Za-z_][A-Za-z0-9_]{0,63}$", environment))
      ]
    ]]))
    error_message = "Infrastructure identifiers must be lowercase letters, digits and underscores; environments must be valid Harness identifiers."
  }
}
