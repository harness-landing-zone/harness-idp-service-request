output "available_types" {
  description = "Infrastructure types, one per type folder holding infrastructure.tpl."
  value       = local.available_types
}

output "infrastructures" {
  description = "Infrastructure Definitions managed from the files, keyed by <environment>/<identifier>."
  value = { for key, infrastructure in harness_platform_infrastructure.this : key => {
    identifier  = infrastructure.identifier
    environment = infrastructure.env_id
    type        = infrastructure.type
  } }
}

output "infrastructure_files" {
  description = "Infrastructure files this run declares, existing and newly written. New ones still need to be committed and pushed."
  value       = { for key, file in local.files : key => file.path }
}
