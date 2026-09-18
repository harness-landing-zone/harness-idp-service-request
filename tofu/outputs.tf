output "available_types" {
  description = "Service types, one per template file."
  value       = module.harness_services.available_types
}

output "services" {
  description = "Harness Services managed from the service files."
  value       = module.harness_services.services
}

output "service_files" {
  description = "Service files this run declares. New ones still need to be committed and pushed."
  value       = module.harness_services.service_files
}

output "infrastructures" {
  description = "Infrastructure Definitions managed from the infrastructure files, keyed by <environment>/<identifier>."
  value       = module.harness_infrastructures.infrastructures
}

output "infrastructure_files" {
  description = "Infrastructure files this run declares. New ones still need to be committed and pushed."
  value       = module.harness_infrastructures.infrastructure_files
}
