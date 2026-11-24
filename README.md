# GroundWerk

GroundWerk is a starter kit for .NET services on Azure with AI-assisted delivery. An AI developer takes stories from the board to pull requests, and a person approves every merge and infrastructure change. Each PR build runs the tests, scans the commits for secrets with gitleaks and has to pass SonarQube Cloud's quality gate, and Renovate opens the PRs that keep packages and pipeline templates up to date. Azure DevOps itself, from the repos' branch policies to the pipelines and their permissions, is set up by the Terraform in infra/azdo. The sample app is one host that runs in two roles, as the API and as the jobs, with Domain, Application, Infrastructure, Contracts and Database projects ready for a service's code. Code that only this solution's apps share stays a project here, never a package, while the pipeline templates and the shared packages each have a repo of their own, which other repos take by version.

## Build, test and run

Work in the dev container, which has the .NET SDK and every tool this repo uses: on the dev VM, open the repo in VS Code and choose Reopen in Container (docs/adr/0007). Every package comes from nuget.org, GroundWerk.InnerSource's included, so a restore needs no sign-in (docs/adr/0014). Build and test with `dotnet run build.cs`, the same command the pipelines run, which leaves the test results and coverage, any packages and the published Host and dacpac in artifacts/. Run the solution locally with `dotnet run --project src/GroundWerk.AppHost`, which starts the Host as the API and as the jobs and prints a link to the Aspire dashboard, which shows their traces, metrics and logs. In VS Code, F5 starts it with the debugger attached to both. To run one role on its own, use `dotnet run --project src/GroundWerk.Host`, adding `-- --Role=jobs` for the jobs.

## Working here

AGENTS.md has the layout, the conventions, how branches, commits and PRs are named, and the Definitions of Done and Ready. docs/adr records each design decision and the alternative it was chosen over.
