# Example root: configures the provider (terraform.tf), resolves where the
# config files live, and calls the modules. All logic is in the modules.

locals {
  # <configs root>/organizations/<org folder>/projects/<project key>/<category>
  configs_dir         = var.configs_root != null ? var.configs_root : abspath("${path.module}/${var.configs_relative_path}")
  project_dir         = "${local.configs_dir}/organizations/${coalesce(var.organization_folder, var.organization_identifier)}/projects/${coalesce(var.project_key, var.project_identifier)}"
  services_dir        = "${local.project_dir}/services"
  infrastructures_dir = "${local.project_dir}/infrastructures"

  # A Service request may carry where it deploys, per environment:
  #   infrastructure = { dev = { connector_ref = "...", project = "...", region = "..." } }
  # That part goes to the infrastructure module, named after the Service.
  infrastructure_requests = {
    for type, group in var.services : type => {
      for id, service in group : id => service.infrastructure if can(service.infrastructure)
    }
  }
}

module "harness_services" {
  source = "./modules/harness-services"

  org_id        = var.organization_identifier
  project_id    = var.project_identifier
  services_dirs = [local.services_dir]
  services      = var.services
  write_files   = var.write_files
}

module "harness_infrastructures" {
  source = "./modules/harness-infrastructures"

  org_id               = var.organization_identifier
  project_id           = var.project_identifier
  infrastructures_dirs = [local.infrastructures_dir]
  infrastructures      = local.infrastructure_requests
  write_files          = var.write_files
  verify_environments  = var.verify_environments
}
