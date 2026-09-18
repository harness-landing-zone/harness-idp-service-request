# Infrastructure config for a Helm Service in one environment: where it
# deploys. One file per Service and environment.
# Inputs: identifier, name, environment, infrastructure_type, config:
#   connector_ref (required) Kubernetes cluster connector, with its scope prefix if not project level
#   namespace     (required) deployment namespace
# Values pass through jsonencode so odd characters cannot break the YAML.
infrastructure_type: ${infrastructure_type}
environment: ${environment}
name: ${jsonencode(name)}
yaml:
  infrastructureDefinition:
    name: ${jsonencode(name)}
    identifier: ${identifier}
    environmentRef: ${environment}
    deploymentType: Kubernetes
    type: KubernetesDirect
    spec:
      connectorRef: ${jsonencode(config.connector_ref)}
      namespace: ${jsonencode(config.namespace)}
      releaseName: release-<+INFRA_KEY_SHORT_ID>
    allowSimultaneousDeployments: false
