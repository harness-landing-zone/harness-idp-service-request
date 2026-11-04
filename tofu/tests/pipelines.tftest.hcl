# Plan only: no Harness calls or config file writes.
mock_provider "harness" {}
mock_provider "local" {}

variables {
  org_id        = "test_org"
  project_id    = "test_project"
  pipelines_dir = "tests/fixtures/pipelines"
  write_files   = true
  services = {
    helm = {
      helm_test = {
        name = "Helm test"
        pipeline = {
          template_ref  = "account.service_request_helm_deploy"
          version_label = "v1"
        }
      }
    }
    cloudrun = {
      cloudrun_test = {
        name = "Cloud Run test"
        pipeline = {
          template_ref  = "account.service_request_cloudrun_deploy"
          version_label = "v2"
        }
      }
    }
  }
}

run "render_helm_and_cloudrun" {
  command = plan
  module {
    source = "./modules/harness-pipelines"
  }

  assert {
    condition = (
      toset(keys(output.pipelines)) == toset(["existing_deploy", "helm_test_deploy", "cloudrun_test_deploy"]) &&
      harness_platform_pipeline.this["helm_test_deploy"].org_id == "test_org" &&
      harness_platform_pipeline.this["helm_test_deploy"].project_id == "test_project"
    )
    error_message = "New pipelines must join the existing config in the requested project."
  }
  assert {
    condition = (
      yamldecode(local_file.rendered["helm_test_deploy"].content).yaml.pipeline.template.templateRef == "account.service_request_helm_deploy" &&
      yamldecode(local_file.rendered["helm_test_deploy"].content).yaml.pipeline.template.versionLabel == "v1" &&
      { for v in yamldecode(local_file.rendered["helm_test_deploy"].content).yaml.pipeline.template.templateInputs.variables : v.name => v.value } == {
        service_identifier     = "helm_test"
        environment_identifier = "<+input>"
        git_commit             = "<+input>"
      } &&
      !can(yamldecode(local_file.rendered["helm_test_deploy"].content).yaml.pipeline.template.templateInputs.stages)
    )
    error_message = "Helm must bind its Service and retain environment/git inputs without Cloud Run stage inputs."
  }
  assert {
    condition = (
      yamldecode(harness_platform_pipeline.this["cloudrun_test_deploy"].yaml).pipeline.template == yamldecode(local_file.rendered["cloudrun_test_deploy"].content).yaml.pipeline.template &&
      yamldecode(local_file.rendered["cloudrun_test_deploy"].content).yaml.pipeline.template.templateRef == "account.service_request_cloudrun_deploy" &&
      yamldecode(local_file.rendered["cloudrun_test_deploy"].content).yaml.pipeline.template.versionLabel == "v2" &&
      { for v in yamldecode(local_file.rendered["cloudrun_test_deploy"].content).yaml.pipeline.template.templateInputs.variables : v.name => v.value } == {
        service_identifier     = "cloudrun_test"
        environment_identifier = "<+input>"
        runner_connector_ref   = "<+input>"
        runner_namespace       = "<+input>"
      } &&
      yamldecode(local_file.rendered["cloudrun_test_deploy"].content).yaml.pipeline.template.templateInputs.stages[0].stage.spec.service.serviceInputs == "<+input>"
    )
    error_message = "Cloud Run must pin the selected version and keep its runner and Deploy stage inputs in both file and Harness YAML."
  }
}

run "no_selection_preserves_existing" {
  command = plan
  module {
    source = "./modules/harness-pipelines"
  }
  variables {
    services = { helm = { no_pipeline = { name = "No pipeline selected" } } }
  }
  assert {
    condition = (
      keys(output.pipelines) == ["existing_deploy"] &&
      local_file.rendered["existing_deploy"].content == file("tests/fixtures/pipelines/existing_deploy.yaml")
    )
    error_message = "A request without pipeline selection must preserve existing pipeline content and create no new pipeline."
  }
}

run "reject_non_account_template" {
  command = plan
  module {
    source = "./modules/harness-pipelines"
  }
  variables {
    services = { helm = { invalid = {
      name     = "Invalid scope"
      pipeline = { template_ref = "org.template", version_label = "v1" }
    } } }
  }
  expect_failures = [local_file.rendered["invalid_deploy"], harness_platform_pipeline.this["invalid_deploy"]]
}

run "reject_unpinned_version" {
  command = plan
  module {
    source = "./modules/harness-pipelines"
  }
  variables {
    services = { helm = { invalid = {
      name     = "Unpinned version"
      pipeline = { template_ref = "account.template", version_label = "<+input>" }
    } } }
  }
  expect_failures = [local_file.rendered["invalid_deploy"], harness_platform_pipeline.this["invalid_deploy"]]
}
