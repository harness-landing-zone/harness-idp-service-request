# inputs match the Helm and Cloud Run service_request templates; adapt the inputs before using a different contract.
name: ${jsonencode(name)}
yaml:
  pipeline:
    template:
      templateRef: ${jsonencode(pipeline.template_ref)}
      versionLabel: ${jsonencode(pipeline.version_label)}
      templateInputs:
        variables:
          - name: service_identifier
            type: String
            value: ${jsonencode(service_id)}
          - name: environment_identifier
            type: String
            value: <+input>
%{ if service_type == "helm" ~}
          - name: git_commit
            type: String
            value: <+input>
%{ endif ~}
%{ if service_type == "cloudrun" ~}
          - name: runner_connector_ref
            type: String
            value: <+input>
          - name: runner_namespace
            type: String
            value: <+input>
        stages:
          - stage:
              identifier: Deploy
              type: Deployment
              spec:
                service:
                  serviceInputs: <+input>
%{ endif ~}
