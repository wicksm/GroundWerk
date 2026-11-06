# GroundWerk

GroundWerk holds everything the Accounting team ships for supplier master data: the API and its Hangfire jobs, the ingestors, the poller and the outbox relay, the SQL database project, and the team's own Terraform, Helm charts, performance tests and API Management configuration. Code that only these apps share is a project in this solution, never a package, so a change to a table they share is one PR whose tests cover them all. What many teams consume by version has a repo of its own: GroundWerk.PipelineTemplates holds the pipeline templates, InnerSource the company-wide packages for auth, OpenTelemetry and the fake token issuer, and GroundWerk.Packages the packages something outside this repo consumes, while TerraformModules and ProducerStubs stand in for the platform team's modules and other teams' producers.

## Build, test and run

You need the .NET 10 SDK. Build with `dotnet build GroundWerk.slnx` and test with `dotnet test --solution GroundWerk.slnx`. Run the Host with `dotnet run --project src/GroundWerk.Host`, which starts it as the API, or add `-- --Role=jobs` to start it as the jobs.

## Working here

AGENTS.md has the layout, the conventions, how branches, commits and PRs are named, and the Definitions of Done and Ready. docs/adr records each design decision and the alternative it was chosen over.
