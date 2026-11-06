# pipelines

One YAML file per pipeline, named after it. azdo-terraform.yml is pipeline azdo-terraform, which plans and applies infra/azdo, and templates/ holds steps that more than one pipeline uses. The app's builds and deploys will extend a template from GroundWerk.PipelineTemplates and use path filters, so each app builds and deploys on its own.
