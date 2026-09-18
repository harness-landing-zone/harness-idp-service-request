locals {
  # A type is a folder of templates shared by the modules:
  # <templates_dir>/<type>/infrastructure.tpl
  templates_dir   = coalesce(var.templates_dir, "${path.module}/../templates")
  available_types = sort([for file in fileset(local.templates_dir, "*/infrastructure.tpl") : dirname(file)])
  write_dir       = coalesce(var.write_dir, var.infrastructures_dirs[length(var.infrastructures_dirs) - 1])

  # Existing infrastructure: one YAML file each, in a folder per environment:
  # <dir>/<environment>/<identifier>.yaml. When the same relative path exists in
  # more than one directory the later directory wins. A directory that does not
  # exist yet simply has no files.
  found = merge([
    for dir in var.infrastructures_dirs : { for file in try(fileset(dir, "*/*.yaml"), []) : file => dir }
  ]...)

  # The key is <environment>/<identifier>; the identifier is the file name with
  # hyphens turned into underscores. Identifiers are unique per environment.
  existing_files = {
    for file, dir in local.found :
    "${dirname(file)}/${replace(trimsuffix(basename(file), ".yaml"), "-", "_")}" => file
  }

  # A file that is not valid YAML decodes to null and is reported by a guard.
  existing_infrastructures = {
    for key, file in local.existing_files : key => try(yamldecode(file("${local.found[file]}/${file}")), null)
  }

  # New requests arrive as type -> identifier -> environment. They are flattened
  # to one map by <environment>/<identifier>, carrying the type with them.
  request_list = flatten([
    for type, group in var.infrastructures : [
      for id, environments in group : [
        for environment, config in environments : {
          key                 = "${environment}/${id}"
          identifier          = id
          environment         = environment
          infrastructure_type = type
          name                = try(config.name, replace(id, "_", "-"))
          config              = config
        }
      ]
    ]
  ])
  requests = { for request in local.request_list : request.key => request... }

  # jsonencode escapes <, > and & for HTML safety. Inside a quoted YAML string
  # they are harmless, so they are restored to keep <+input> readable.
  rendered = {
    for key, matches in local.requests : key => replace(replace(replace(templatefile(
      "${local.templates_dir}/${matches[0].infrastructure_type}/infrastructure.tpl",
      matches[0]
    ), "\\u003c", "<"), "\\u003e", ">"), "\\u0026", "&") if contains(local.available_types, matches[0].infrastructure_type)
  }

  # Every run sees the complete set: existing files plus new requests. A request
  # for an existing <environment>/<identifier> replaces it.
  configs = merge(local.existing_infrastructures, { for key, text in local.rendered : key => try(yamldecode(text), null) })

  # A usable config names its type and environment and has a typed definition.
  valid = {
    for key, cnf in local.configs : key => try(
      cnf.name != null && cnf.infrastructure_type != null && cnf.environment == dirname(key) &&
      cnf.yaml.infrastructureDefinition.type != null && cnf.yaml.infrastructureDefinition.deploymentType != null &&
      cnf.yaml.infrastructureDefinition.spec != null,
      false
    )
  }
  usable = { for key, cnf in local.configs : key => cnf if local.valid[key] }

  # One file per infrastructure, always declared, so adding one never removes
  # another. An existing file keeps its own content and place; a new request
  # writes its render. Deleting a file in Git retires the file and its
  # Infrastructure Definition.
  files = merge(
    { for key, file in local.existing_files : key => {
      path    = "${local.found[file]}/${file}"
      content = file("${local.found[file]}/${file}")
    } },
    { for key, text in local.rendered : key => {
      path    = contains(keys(local.existing_files), key) ? "${local.found[local.existing_files[key]]}/${local.existing_files[key]}" : "${local.write_dir}/${key}.yaml"
      content = text
    } }
  )

  environments = toset([for key, cnf in local.usable : dirname(key)])
  infrastructure_tags = {
    for key, cnf in local.usable : key => {
      for name, value in merge(var.tags, try(lookup(cnf, "tags", {}), {})) : name => replace(tostring(value), ":", "/")
    }
  }
}

# Guards: fail at plan time, naming the request or the file.
resource "terraform_data" "request_guard" {
  for_each = { for key, matches in local.requests : key => matches }
  lifecycle {
    precondition {
      condition     = length(each.value) == 1
      error_message = "Infrastructure ${each.key} is requested under more than one type. Identifiers are unique per environment, not per type."
    }
    precondition {
      condition     = contains(local.available_types, each.value[0].infrastructure_type)
      error_message = "Infrastructure ${each.key} has unknown type \"${each.value[0].infrastructure_type}\". Available types: ${join(", ", local.available_types)}."
    }
    precondition {
      condition     = lookup(local.valid, each.key, false) || !contains(local.available_types, each.value[0].infrastructure_type)
      error_message = "${each.value[0].infrastructure_type}/infrastructure.tpl did not render a valid infrastructure config for ${each.key}: expected name, infrastructure_type, environment and yaml.infrastructureDefinition with type, deploymentType and spec."
    }
  }
}

resource "terraform_data" "config_guard" {
  for_each = local.existing_infrastructures
  lifecycle {
    precondition {
      condition     = local.valid[each.key] || contains(keys(local.requests), each.key)
      error_message = "${local.files[each.key].path} is not a valid infrastructure config: expected name, infrastructure_type, an environment matching its folder (${dirname(each.key)}) and yaml.infrastructureDefinition with type, deploymentType and spec."
    }
  }
}

# The environments are created elsewhere, by the project bootstrap. Looking them
# up makes a missing one fail at plan time, by name.
data "harness_platform_environment" "target" {
  for_each   = var.verify_environments ? local.environments : toset([])
  identifier = each.value
  org_id     = var.org_id
  project_id = var.project_id
}

resource "local_file" "rendered" {
  for_each        = var.write_files ? local.files : {}
  filename        = each.value.path
  content         = each.value.content
  file_permission = "0644"
}

# Existing and requested infrastructure take the same path into Harness.
resource "harness_platform_infrastructure" "this" {
  for_each = local.usable
  depends_on = [
    terraform_data.request_guard,
    terraform_data.config_guard,
    data.harness_platform_environment.target,
  ]

  identifier      = basename(each.key)
  name            = each.value.name
  org_id          = var.org_id
  project_id      = var.project_id
  env_id          = dirname(each.key)
  type            = each.value.yaml.infrastructureDefinition.type
  deployment_type = each.value.yaml.infrastructureDefinition.deploymentType
  tags            = [for name, value in local.infrastructure_tags[each.key] : "${name}:${value}"]

  yaml = yamlencode({ infrastructureDefinition = merge(
    each.value.yaml.infrastructureDefinition,
    {
      identifier        = basename(each.key)
      name              = each.value.name
      orgIdentifier     = var.org_id
      projectIdentifier = var.project_id
      environmentRef    = dirname(each.key)
      tags              = local.infrastructure_tags[each.key]
    }
  ) })
}
