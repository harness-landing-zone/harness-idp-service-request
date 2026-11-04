variable "org_id" {
  description = "Harness organization identifier that owns the project."
  type        = string
}

variable "project_id" {
  description = "Harness project identifier that owns the pipelines."
  type        = string
}

variable "pipelines_dir" {
  description = "Directory of pipeline configs named <identifier>.yaml. A missing directory is empty; deleting a config plans deletion of its managed pipeline."
  type        = string
}

variable "services" {
  description = "Service requests grouped by type and identifier, optionally carrying pipeline = { template_ref, version_label }."
  type        = any
  default     = {}
}

variable "write_files" {
  description = "Write existing and requested pipeline configs to disk."
  type        = bool
  default     = false
}

variable "resource_dependencies" {
  description = "Services and infrastructure that must exist before creating pipelines; not used by the file renderer."
  type        = any
  default     = []
}
