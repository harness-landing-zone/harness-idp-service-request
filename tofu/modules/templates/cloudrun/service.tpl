# Service config file: name, description, tags
# and the Harness Service under yaml.service. Rendered for Google Cloud Run.
# Inputs: identifier, service, config (the type's own values from the request).
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
      type: GoogleCloudRun
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
              identifier: cloud_run
              type: GoogleCloudRunService
              spec:
                store:
                  type: Github
                  spec:
                    connectorRef: ${jsonencode(config.git.connector_ref)}
                    repoName: ${jsonencode(config.git.repository)}
                    gitFetchType: Commit
                    commitId: ${try(jsonencode(config.git.commit), "<+input>")}
                    paths:
                      - ${jsonencode(config.git.path)}
        artifacts:
          primary:
            primaryArtifactRef: container
            sources:
              - identifier: container
                type: DockerRegistry
                spec:
                  connectorRef: ${try(jsonencode(config.artifact.connector_ref), "<+input>")}
                  imagePath: ${try(jsonencode(config.artifact.image_path), "<+input>")}
                  tag: ${try(jsonencode(config.artifact.tag), "<+input>")}
    gitOpsEnabled: false
