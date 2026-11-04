# Exercise the root's Service -> infrastructure/pipeline request handoff.
mock_provider "harness" {}
mock_provider "local" {}

run "request_creates_all_three_configs" {
  command = plan
  variables {
    organization_identifier = "test_org"
    project_identifier      = "test_project"
    configs_relative_path   = "tests/fixtures/configs"
    write_files             = true
    services = {
      helm = {
        requested_service = {
          name  = "Requested service"
          owner = "test_team"
          config = {
            chart  = { connector_ref = "account.helm", name = "podinfo", version = "6.17.0" }
            values = { connector_ref = "account.git", repository = "values", path = "values.yaml" }
          }
          infrastructure = { dev = { connector_ref = "test_cluster", namespace = "default" } }
          pipeline = {
            template_ref  = "account.service_request_helm_deploy"
            version_label = "v1"
          }
        }
      }
    }
  }
  assert {
    condition = (
      keys(output.services) == ["requested_service"] &&
      keys(output.infrastructures) == ["dev/requested_service"] &&
      keys(output.pipelines) == ["requested_service_deploy"] &&
      endswith(output.service_files["requested_service"], "/test_project/services/helm/requested_service.yaml") &&
      endswith(output.infrastructure_files["dev/requested_service"], "/test_project/infrastructures/dev/requested_service.yaml") &&
      endswith(output.pipeline_files["requested_service_deploy"], "/test_project/pipelines/requested_service_deploy.yaml")
    )
    error_message = "One Service request must produce Service, infrastructure and pipeline resources and config paths in the same project."
  }
}
