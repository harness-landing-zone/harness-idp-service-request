# Infrastructure config for a Cloud Run Service in one environment: where it
# deploys. One file per Service and environment.
# Inputs: identifier, name, environment, infrastructure_type, config:
#   connector_ref (required) GCP connector, with its scope prefix if not project level
#   project       (required) GCP project id, not the project number
#   region        (required) GCP region
# Values pass through jsonencode so odd characters cannot break the YAML.
infrastructure_type: ${infrastructure_type}
environment: ${environment}
name: ${jsonencode(name)}
yaml:
  infrastructureDefinition:
    name: ${jsonencode(name)}
    identifier: ${identifier}
    environmentRef: ${environment}
    deploymentType: GoogleCloudRun
    type: GoogleCloudRun
    spec:
      connectorRef: ${jsonencode(config.connector_ref)}
      project: ${jsonencode(config.project)}
      region: ${jsonencode(config.region)}
    allowSimultaneousDeployments: false
