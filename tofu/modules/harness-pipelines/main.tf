locals {
  templates_dir = "${path.module}/../templates"
  requests = merge([
    for type, group in var.services : {
      for id, service in group : "${id}_deploy" => {
        service_id   = id
        name         = "${service.name}-deploy"
        service_type = type
        pipeline     = service.pipeline
      } if try(service.pipeline, null) != null
    }
  ]...)
  rendered = {
    for id, request in local.requests : id => templatefile(
      "${local.templates_dir}/pipeline.tpl", request
    )
  }
  # Omitted pipeline requests preserve the configs already recorded in Git.
  files = merge(
    { for filename in fileset(var.pipelines_dir, "*.yaml") :
      trimsuffix(filename, ".yaml") => file("${var.pipelines_dir}/${filename}")
    },
    local.rendered
  )
  pipelines = { for id, content in local.files : id => yamldecode(content) }
}

resource "local_file" "rendered" {
  for_each        = var.write_files ? local.files : {}
  filename        = "${var.pipelines_dir}/${each.key}.yaml"
  content         = each.value
  file_permission = "0644"

  lifecycle {
    precondition {
      condition     = can(regex("^[a-zA-Z_][a-zA-Z0-9_$]{0,127}$", each.key))
      error_message = "Pipeline identifier ${each.key} must be valid and at most 128 characters including _deploy."
    }
    precondition {
      condition = try(
        can(regex("^account\\.[a-zA-Z_][a-zA-Z0-9_$]{0,127}$", local.pipelines[each.key].yaml.pipeline.template.templateRef)) &&
        length(trimspace(local.pipelines[each.key].yaml.pipeline.template.versionLabel)) > 0 &&
        local.pipelines[each.key].yaml.pipeline.template.versionLabel != "<+input>",
        false
      )
      error_message = "Pipeline ${each.key} requires an account template reference and explicit version label."
    }
  }
}

resource "harness_platform_pipeline" "this" {
  for_each   = local.pipelines
  depends_on = [var.resource_dependencies]

  identifier = each.key
  name       = each.value.name
  org_id     = var.org_id
  project_id = var.project_id

  yaml = yamlencode({ pipeline = {
    identifier        = each.key
    name              = each.value.name
    orgIdentifier     = var.org_id
    projectIdentifier = var.project_id
    template          = each.value.yaml.pipeline.template
  } })

  lifecycle {
    precondition {
      condition     = can(regex("^[a-zA-Z_][a-zA-Z0-9_$]{0,127}$", each.key)) && try(length(trimspace(each.value.name)) > 0, false)
      error_message = "${each.key}.yaml must have a valid pipeline identifier as its filename and a non-empty name."
    }
    precondition {
      condition = try(
        can(regex("^account\\.[a-zA-Z_][a-zA-Z0-9_$]{0,127}$", each.value.yaml.pipeline.template.templateRef)) &&
        length(trimspace(each.value.yaml.pipeline.template.versionLabel)) > 0 &&
        each.value.yaml.pipeline.template.versionLabel != "<+input>" &&
        can(keys(each.value.yaml.pipeline.template.templateInputs)),
        false
      )
      error_message = "${each.key}.yaml must contain yaml.pipeline.template with an account templateRef, an explicit versionLabel and a templateInputs object."
    }
  }
}
