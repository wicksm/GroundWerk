# GroundWerk

GroundWerk holds everything the Accounting team ships for supplier master data: the API and its Hangfire jobs, the ingestors, the poller and the outbox relay, the SQL database project, and the team's own Terraform, Helm charts, performance tests and API Management configuration. Code that only these apps share is a project in this solution, never a package, so a change to a table they share is one PR whose tests cover them all. What many teams consume by version has a repo of its own: GroundWerk.PipelineTemplates holds the pipeline templates, InnerSource the company-wide packages for auth, OpenTelemetry and the fake token issuer, and GroundWerk.Packages the packages something outside this repo consumes, while TerraformModules and ProducerStubs stand in for the platform team's modules and other teams' producers.

## Build, test and run

Work in the dev container, which has the .NET SDK and every tool this repo uses: on the dev VM, open the repo in VS Code and choose Reopen in Container (docs/adr/0007). Build and test with `dotnet run build.cs`, the same command the pipelines run, which leaves the test results, any packages and the published Host and dacpac in artifacts/. Run the solution locally with `dotnet run --project src/GroundWerk.AppHost`, which starts the Host as the API and as the jobs and prints a link to the Aspire dashboard. In VS Code, F5 starts it with the debugger attached to both. To run one role on its own, use `dotnet run --project src/GroundWerk.Host`, adding `-- --Role=jobs` for the jobs.

## Working here

AGENTS.md has the layout, the conventions, how branches, commits and PRs are named, and the Definitions of Done and Ready. docs/adr records each design decision and the alternative it was chosen over.
