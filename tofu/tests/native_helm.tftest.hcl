# Plan only: check the rendered API payloads and matching deployment template.
mock_provider "harness" {}
mock_provider "local" {}

run "native_helm_service" {
  command = plan
  module {
    source = "./modules/harness-services"
  }
  variables {
    org_id        = "test_org"
    project_id    = "test_project"
    services_dirs = ["tests/fixtures/configs/services"]
    services = { helm = { test = {
      name  = "Helm test"
      owner = "test_team"
      config = {
        chart  = { connector_ref = "account.helm", name = "podinfo", version = "6.17.0" }
        values = { connector_ref = "account.git", repository = "values", path = "values.yaml" }
      }
    } } }
  }
  assert {
    condition = (
      yamldecode(harness_platform_service.this["test"].yaml).service.serviceDefinition.type == "NativeHelm" &&
      yamldecode(harness_platform_service.this["test"].yaml).service.serviceDefinition.spec.manifests[0].manifest.type == "HelmChart" &&
      yamldecode(harness_platform_service.this["test"].yaml).service.serviceDefinition.spec.manifests[1].manifest.spec.store.spec.commitId == "<+input>"
    )
    error_message = "Helm requests must create NativeHelm Services and preserve chart and values commit inputs."
  }
  assert {
    condition = (
      yamldecode(file("../pipelines/templates/service-request-native-helm-deploy.yaml")).template.spec.stages[0].stage.spec.deploymentType == yamldecode(harness_platform_service.this["test"].yaml).service.serviceDefinition.type &&
      yamldecode(file("../pipelines/templates/service-request-native-helm-deploy.yaml")).template.spec.stages[0].stage.spec.service.serviceInputs.serviceDefinition.type == "NativeHelm" &&
      yamldecode(file("../pipelines/templates/service-request-native-helm-deploy.yaml")).template.spec.stages[0].stage.spec.execution.steps[0].step.type == "HelmDeploy" &&
      yamldecode(file("../pipelines/templates/service-request-native-helm-deploy.yaml")).template.spec.stages[0].stage.spec.execution.rollbackSteps[0].step.type == "HelmRollback"
    )
    error_message = "The deployment template must match the NativeHelm Service and use Helm deploy/rollback steps."
  }
}

run "native_helm_infrastructure" {
  command = plan
  module {
    source = "./modules/harness-infrastructures"
  }
  variables {
    org_id               = "test_org"
    project_id           = "test_project"
    infrastructures_dirs = ["tests/fixtures/configs/infrastructures"]
    infrastructures = { helm = { test = { dev = {
      connector_ref = "test_cluster"
      namespace     = "helm-test"
    } } } }
  }
  assert {
    condition = (
      harness_platform_infrastructure.this["dev/test"].deployment_type == "NativeHelm" &&
      harness_platform_infrastructure.this["dev/test"].type == "KubernetesDirect" &&
      yamldecode(harness_platform_infrastructure.this["dev/test"].yaml).infrastructureDefinition.spec.namespace == "helm-test"
    )
    error_message = "Helm infrastructure must use NativeHelm while retaining its Kubernetes connection and namespace."
  }
}
