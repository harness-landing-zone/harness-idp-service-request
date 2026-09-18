# Service config for a Helm chart deployed with the Harness Kubernetes
# deployment type: Harness manages the rollout and versioned rollback, and
# canary or blue-green stay available. Same file format as every other type.
# Inputs: identifier, service, config (the type's own values from the request):
#   chart.connector_ref, chart.name, chart.version   (required) HTTP Helm repo
#   values.connector_ref, values.repository, values.path (required) Git values file
#   values.commit                                     (optional)
#   variables                                         (optional) map of Service variables
# Values pass through jsonencode so odd characters cannot break the YAML.
# A value left out of the config becomes <+input>, chosen when CD runs.
service_type: ${service.service_type}
name: ${jsonencode(service.name)}
description: ${jsonencode(service.description)}
tags:
  owner: ${jsonencode(service.owner)}
  service_type: ${jsonencode(service.service_type)}
yaml:
  service:
    name: ${jsonencode(service.name)}
    identifier: ${identifier}
    serviceDefinition:
      type: Kubernetes
      spec:
%{ if length(try(config.variables, {})) > 0 ~}
        variables:
%{ for name, value in config.variables ~}
          - name: ${name}
            type: String
            value: ${jsonencode(value)}
%{ endfor ~}
%{ endif ~}
        manifests:
          - manifest:
              identifier: chart
              type: HelmChart
              spec:
                store:
                  type: Http
                  spec:
                    connectorRef: ${jsonencode(config.chart.connector_ref)}
                chartName: ${jsonencode(config.chart.name)}
                chartVersion: ${jsonencode(config.chart.version)}
                helmVersion: V3
                skipResourceVersioning: false
                enableDeclarativeRollback: false
          - manifest:
              identifier: values
              type: Values
              spec:
                store:
                  type: Github
                  spec:
                    connectorRef: ${jsonencode(config.values.connector_ref)}
                    repoName: ${jsonencode(config.values.repository)}
                    gitFetchType: Commit
                    commitId: ${try(jsonencode(config.values.commit), "<+input>")}
                    paths:
                      - ${jsonencode(config.values.path)}
    gitOpsEnabled: false
