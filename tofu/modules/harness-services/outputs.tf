output "available_types" {
  description = "Service types, one per template file."
  value       = local.available_types
}

output "services" {
  description = "Harness Services managed from the service files, keyed by identifier."
  value = { for id, service in harness_platform_service.this : id => {
    identifier = service.identifier
    type       = dirname(local.files[id].path) == "." ? null : basename(dirname(local.files[id].path))
  } }
}

output "service_files" {
  description = "Service files this run declares, existing and newly written. New ones still need to be committed and pushed."
  value       = { for id, file in local.files : id => file.path }
}
