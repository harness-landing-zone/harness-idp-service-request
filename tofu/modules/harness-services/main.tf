locals {
  # A type is a folder of templates shared by the modules:
  # <templates_dir>/<type>/service.tpl, infrastructure.tpl, ...
  templates_dir   = coalesce(var.templates_dir, "${path.module}/../templates")
  available_types = sort([for file in fileset(local.templates_dir, "*/service.tpl") : dirname(file)])
  write_dir       = coalesce(var.write_dir, var.services_dirs[length(var.services_dirs) - 1])

  # Existing Services: one YAML file each, grouped in a folder per type:
  # <dir>/<type>/<identifier>.yaml. When the same relative path exists in more
  # than one directory the later directory wins. A directory that does not
  # exist yet simply has no files.
  found = merge([
    for dir in var.services_dirs : {
      for file in try(fileset(dir, "*/*.yaml"), []) : file => dir
    }
  ]...)

  # The file name is the identifier, with hyphens turned into underscores.
  # Identifiers are unique per project, not per type, so every path found for an
  # identifier is kept and duplicates are reported by a guard.
  existing_paths = {
    for file, dir in local.found :
    replace(trimsuffix(basename(file), ".yaml"), "-", "_") => file...
  }
  existing_files = { for id, paths in local.existing_paths : id => paths[0] }

  # A file that is not valid YAML decodes to null and is reported by a guard.
  existing_services = {
    for id, file in local.existing_files : id => try(yamldecode(file("${local.found[file]}/${file}")), null)
  }

  # New requests arrive grouped by type; the group key is the type. They are
  # flattened to one map by identifier, carrying the type with them. Unknown
  # types are reported by a guard.
  requests = merge([
    for type, group in var.services : {
      for id, service in group : id => {
        name         = service.name
        description  = try(service.description, "Service requested through IDP")
        owner        = service.owner
        service_type = type
        config       = try(service.config, {})
      }
    }
  ]...)
  # jsonencode escapes <, > and & for HTML safety. Inside a quoted YAML string
  # they are harmless, so they are restored to keep <+input> readable.
  rendered = {
    for id, service in local.requests : id => replace(replace(replace(templatefile(
      "${local.templates_dir}/${service.service_type}/service.tpl",
      { identifier = id, service = service, config = service.config }
    ), "\\u003c", "<"), "\\u003e", ">"), "\\u0026", "&") if contains(local.available_types, service.service_type)
  }

  # Every run sees the complete set: existing Services plus new requests. A
  # request with the identifier of an existing Service replaces it.
  configs = merge(local.existing_services, { for id, text in local.rendered : id => try(yamldecode(text), null) })

  # A usable config has a name and a Harness Service with a typed definition.
  valid = {
    for id, cnf in local.configs : id => try(
      cnf.name != null && cnf.yaml.service.serviceDefinition.type != null && cnf.yaml.service.serviceDefinition.spec != null,
      false
    )
  }

  # One file per Service, always declared, so adding a Service never removes
  # another. An existing file keeps its own content and place; a new request
  # writes its render into the write directory. Deleting a file in Git retires
  # the file and its Harness Service.
  files = merge(
    { for id, file in local.existing_files : id => {
      path    = "${local.found[file]}/${file}"
      content = file("${local.found[file]}/${file}")
    } },
    { for id, text in local.rendered : id => {
      path    = contains(keys(local.existing_files), id) ? "${local.found[local.existing_files[id]]}/${local.existing_files[id]}" : "${local.write_dir}/${local.requests[id].service_type}/${id}.yaml"
      content = text
    } }
  )
}

# Guards: fail at plan time, naming the request or the file.
resource "terraform_data" "request_guard" {
  for_each = { for id, request in local.requests : id => request.service_type }
  lifecycle {
    precondition {
      condition     = contains(local.available_types, each.value)
      error_message = "Service ${each.key} has unknown service_type \"${each.value}\". Available types: ${join(", ", local.available_types)}."
    }
    precondition {
      condition     = lookup(local.valid, each.key, false) || !contains(local.available_types, each.value)
      error_message = "${each.value}/service.tpl did not render a valid service config for Service ${each.key}: expected name and yaml.service.serviceDefinition with type and spec."
    }
    precondition {
      condition     = !contains(keys(local.existing_files), each.key) || dirname(local.existing_files[each.key]) == each.value
      error_message = "Service ${each.key} is requested as ${each.value} but already exists as ${lookup(local.existing_files, each.key, "")}. Identifiers are unique per project, not per type."
    }
  }
}

resource "terraform_data" "config_guard" {
  for_each = local.existing_services
  lifecycle {
    precondition {
      condition     = length(local.existing_paths[each.key]) == 1
      error_message = "Service identifier ${each.key} is used by more than one file: ${join(", ", local.existing_paths[each.key])}. Identifiers are unique per project, not per type."
    }
    precondition {
      condition     = local.valid[each.key] || contains(keys(local.requests), each.key)
      error_message = "${local.files[each.key].path} is not a valid service config: expected name and yaml.service.serviceDefinition with type and spec."
    }
    precondition {
      condition     = try(each.value.service_type, null) == dirname(local.existing_files[each.key]) || contains(keys(local.requests), each.key)
      error_message = "${local.files[each.key].path} must state its type: expected service_type: ${dirname(local.existing_files[each.key])} to match its folder, found ${try(each.value.service_type, "none")}."
    }
  }
}

resource "local_file" "rendered" {
  for_each        = var.write_files ? local.files : {}
  filename        = each.value.path
  content         = each.value.content
  file_permission = "0644"
}

# Harness stores tags as key:value and splits on the colon, so a value holding a
# colon (group:account/web) is cut short and every plan shows a change. Tag
# values are made colon-free once, here, for both the tag list and the YAML.
locals {
  service_tags = {
    for id, cnf in local.configs : id => {
      for key, value in merge(var.tags, try(lookup(cnf, "tags", {}), {})) : key => replace(tostring(value), ":", "/")
    }
  }
}

# Existing and requested Services take the same path into Harness.
resource "harness_platform_service" "this" {
  for_each   = { for id, cnf in local.configs : id => cnf if local.valid[id] }
  depends_on = [terraform_data.request_guard, terraform_data.config_guard]

  identifier  = each.key
  name        = each.value.name
  description = lookup(each.value, "description", "Service requested through IDP")
  org_id      = var.org_id
  project_id  = var.project_id
  tags        = [for key, value in local.service_tags[each.key] : "${key}:${value}"]

  yaml = yamlencode({ service = {
    identifier        = each.key
    name              = each.value.name
    description       = lookup(each.value, "description", "Service requested through IDP")
    tags              = local.service_tags[each.key]
    orgIdentifier     = var.org_id
    projectIdentifier = var.project_id
    serviceDefinition = each.value.yaml.service.serviceDefinition
    gitOpsEnabled     = try(each.value.yaml.service.gitOpsEnabled, false)
  } })
}
