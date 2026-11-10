# pipelines

One YAML file per pipeline, named after it. azdo-terraform.yml is pipeline azdo-terraform, which plans and applies infra/azdo, and templates/ holds steps that more than one pipeline uses. The app's builds and deploys will extend a template from GroundWerk.PipelineTemplates and use path filters, so each app builds and deploys on its own. Builds run `dotnet run build.cs`, which owns compile, test, pack and publish, and check out with `fetchDepth: 0` and `fetchTags: true`, since versions come from git tags (docs/adr/0005).
