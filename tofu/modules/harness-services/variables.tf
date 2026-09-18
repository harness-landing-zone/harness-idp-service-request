##############################################################################
# Scope. The caller owns the organization and project; this module only uses them.
##############################################################################

variable "org_id" {
  description = "Harness organization identifier that owns the project."
  type        = string
}

variable "project_id" {
  description = "Harness project identifier that owns the Services."
  type        = string
}

variable "tags" {
  description = "[Optional] Tags added to every Service, merged under the Service's own tags."
  type        = map(string)
  default     = {}
}

##############################################################################
# Where Service files live. The caller resolves paths; this module does not
# know about organizations/ or projects/ folders.
##############################################################################

variable "services_dirs" {
  description = "Absolute directories holding Service files as <type>/<identifier>.yaml. Later directories win when the same relative path exists in more than one, so a defaults directory can come first. A directory that does not exist yet is treated as empty."
  type        = list(string)

  validation {
    condition     = length(var.services_dirs) > 0
    error_message = "Give at least one services directory."
  }
}

variable "write_dir" {
  description = "[Optional] Directory new requests are written to. Defaults to the last entry of services_dirs."
  type        = string
  default     = null
}

variable "write_files" {
  description = "[Optional] Write Service files to disk: a new request writes its render, an existing file keeps its own content. Leave false for a read-only caller that only creates Services from files."
  type        = bool
  default     = false
}

variable "templates_dir" {
  description = "[Optional] Directory of type folders, each holding service.tpl. Defaults to the templates folder shipped next to this module."
  type        = string
  default     = null
}

##############################################################################
# Requests
##############################################################################

variable "services" {
  description = <<-EOT
    [Optional] Requested Services grouped by type, then keyed by identifier, for
    example from an IDP form:  services = { cloudrun = { orders_api = { ... } } }
    The group key is the type: it selects <type>.tpl and the folder <type>/ the
    file is written to. Each entry has:
      name        (required) display name
      owner       (required) owning team reference
      description (optional)
      config      (optional) the values that type's template reads
    Requests join the existing Services found in services_dirs. The type is any
    because each service type has its own config shape, and a typed map would
    force every entry into one common shape.
  EOT
  type        = any
  default     = {}

  validation {
    condition = alltrue(flatten([for type, group in var.services : [
      for id, service in group : can(regex("^[a-z][a-z0-9_]{0,62}$", id))
    ]]))
    error_message = "Service identifiers must be lowercase letters, digits and underscores, starting with a letter."
  }

  validation {
    condition = (
      length(flatten([for type, group in var.services : keys(group)])) ==
      length(distinct(flatten([for type, group in var.services : keys(group)])))
    )
    error_message = "A Service identifier is requested under more than one type. Identifiers are unique per project, not per type."
  }

  validation {
    condition = alltrue(flatten([for type, group in var.services : [
      for id, service in group : alltrue([
        for key in ["name", "owner"] : try(length(trimspace(service[key])) > 0, false)
      ])
    ]]))
    error_message = "Every requested Service needs a non-empty name and owner."
  }
}
