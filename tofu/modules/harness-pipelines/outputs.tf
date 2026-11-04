output "pipelines" {
  description = "Project pipelines managed from saved configuration files, keyed by identifier."
  value       = { for id, pipeline in harness_platform_pipeline.this : id => pipeline.identifier }
}

output "pipeline_files" {
  description = "Existing and requested pipeline config paths."
  value       = { for id, content in local.files : id => "${var.pipelines_dir}/${id}.yaml" }
}
