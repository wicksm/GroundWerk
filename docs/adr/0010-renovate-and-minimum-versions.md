# 10. Renovate opens upgrade PRs as its own identity, and builds hold to minimum versions

Status: Accepted

## Context

A new version of a shared package or template should reach every repo that uses it without anyone filing the work, and after an announced deadline no build should stay below a version its owners require (CICD-17). The project's repos pin GroundWerk.InnerSource's packages by version in Directory.Packages.props, the ci template by release tag in each pipeline's repository resource (CICD-1), and each task by its major version. Renovate finds new versions and opens PRs, and on Azure DevOps it runs in a pipeline. Its docs run it as the pipeline's build service, but every pipeline in the project runs as that service, and from the ci template's NuGetAuthenticate step on, a PR build's own code can read its token (docs/adr/0009).

## Decision

- Pipeline run-renovate runs Renovate 44.240.0, pinned with its lockfile in tools/renovate, on the pool on weekdays at 11:00 UTC and whenever a person runs it, both from main. tools/renovate/config.js is its whole config, so the repos have no renovate.json.
- It signs in as groundwerk-renovate, an Entra ID service principal with a Basic seat, through the renovate service connection with workload identity federation, so it holds no secret. Only pipeline run-renovate may use the connection, and only from main.
- groundwerk-renovate is in group Renovate, which reads the project, creates branches and opens PRs in all three repos, reads the innersource feed and edits work items in area Platform. main denies it Contribute, so it pushes only to the branches it creates and never completes a PR. Each PR links Feature 21, "Upgrades open their own PRs", as main's policy needs, and a person approves and completes it.
- It moves GroundWerk.InnerSource's packages to their new versions, the ci template's tag in each pipeline's repository resource through its Azure Pipelines manager, and every task in the pipelines and templates through a custom regex manager, since the Azure Pipelines manager skips a task inside a condition. Packages from nuget.org stay as they are.
- From v1.2.0, the ci template checks every package a build uses, including those it gets through another package, against the minimums in variable group minimum-versions, which infra/azdo/minimum-versions.tf sets. A package below its minimum warns until the minimum's deadline and fails the build from that day on, in UTC, so a new minimum reaches every build on the template at once, with no new tag.

## Alternatives considered

- The project's build service, which needs no seat. Every pipeline's token could then open and approve PRs, PR builds running a PR's own code included.
- A personal access token, which someone renews by hand and which acts as whoever made it.
- Minimums in the template, which reach only the pipelines that move to its new tag, so a repo that left the upgrade PRs open would never be held to them.

## Consequences

- groundwerk-renovate takes a Basic seat, the fifth by the guides' count, so the next identity that needs Repos costs a paid seat.
- No package's install script runs, so RE2, the regex engine Renovate would rather use, isn't built, and Renovate uses JavaScript's own, as the pipeline tells it to. Only config.js gives it patterns, so RE2's guard against harmful patterns isn't needed.
- npm reports advisories in packages that Renovate brings, which its later versions fix. Renovate doesn't move itself to a new version, so a person does that in tools/renovate through a PR.
- Renovate finds tasks' new major versions in its own public lists of Azure Pipelines' built-in and Marketplace tasks, not in the organization's installed extensions.
- From a minimum's deadline on, every build below it fails until its repo takes the upgrade, PR builds included.
