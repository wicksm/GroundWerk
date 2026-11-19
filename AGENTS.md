# AGENTS.md

How to work in GroundWerk, for people and coding agents. A PR that changes a convention changes this file too.

## Layout

- `GroundWerk.slnx` is the one solution. Add each new project to it with `dotnet sln GroundWerk.slnx add`.
- `build.cs`: the build script, which .NET 10 runs as a file-based app. Its Bullseye targets restore, build, test, pack and publish, so a pipeline's YAML only runs it (docs/adr/0005). Its `#:package` lines carry no versions, since those live in Directory.Packages.props.
- `.devcontainer/`: the image that VS Code's dev container and the pipelines' container jobs run in, with every tool pinned and checked against its checksum, and the pre-commit hook that runs gitleaks (docs/adr/0007). A PR that moves Aspire.AppHost.Sdk in global.json moves ASPIRE_CLI_VERSION in its Dockerfile too.
- `.vscode/launch.json`: F5 starts the AppHost through VS Code's Aspire extension, with the debugger attached to api and jobs.
- `.claude/`: Claude Code's project skills, in `skills/`, and subagents, in `agents/`. The work-on-user-story skill and its subagent, story-coder, set the same model and effort in their frontmatter, so a PR that changes one changes both (docs/adr/0011).
- `src/GroundWerk.Domain`: entities, value objects and the domain's rules, including the field enums that the database's overridable-field registry mirrors.
- `src/GroundWerk.Application`: the handlers that the API and the jobs both call, validation and the unit of work.
- `src/GroundWerk.Infrastructure`: the EF Core DbContext and its mappings, the interceptors and the outbox writer.
- `src/GroundWerk.Contracts`: the published event types and the AsyncAPI source. Other teams code against them, so they stay plain types.
- `src/GroundWerk.Database`: the SQL project, one file per object, built into a dacpac. It owns the schema: EF Core maps to it and never creates or changes it, so there are no migrations and no EnsureCreated.
- `src/GroundWerk.Host`: the one ASP.NET Core host, built into one image from one Dockerfile. Its Role setting, api or jobs, picks what a process runs (docs/adr/0002).
- `src/GroundWerk.AppHost`: the Aspire AppHost, which is how to run the solution locally. It starts the Host as api and as jobs, and phase 2 adds SQL Server, Redis, the Event Hubs emulator and Azurite to it. It's for local runs and tests only, since deploys are Helm and Terraform (docs/adr/0003).
- `src/GroundWerk.Workers.<Name>`: one project per worker as each arrives: ConnectIngestor, SyncIngestor, TenantIngestor, Poller and OutboxRelay. Workers use Microsoft.Data.SqlClient and never reference Infrastructure or its DbContext.
- `tests/GroundWerk.UnitTests`, with `tests/GroundWerk.IntegrationTests` and `tests/GroundWerk.ContractTests` when they arrive, and k6 scripts in `perf/`.
- `infra/azdo`: the Terraform that configures Azure DevOps, planned and applied by pipeline azdo-terraform. The service's own Terraform and its Helm charts get folders of their own under `infra/`.
- `pipelines/`: one YAML file per pipeline, named after it, such as `azdo-terraform.yml`, with steps that more than one pipeline uses in `pipelines/templates`.
- A pipeline that can reach a secret or a service connection keeps it behind an Only main check, since a push to any branch can start a pipeline with that branch's copy of its YAML (docs/adr/0006). The PR builds' two connections, registry-pull and sonarqube-cloud, are the exception, since PR builds need them: they can do little beyond pulling the build image and sending SonarQube Cloud an analysis, and only pipelines build-groundwerk and innersource-ci may use them (docs/adr/0008, docs/adr/0009).
- `tools/`: one folder per tool that a pipeline runs and that isn't part of the product. `tools/ai-developer` is the AI developer, which pipeline ai-developer runs to take one user story or bug tagged ai-developer to one PR (docs/adr/0006). Check and test it with `npm run check` and `npm test` in that folder. `tools/renovate` is Renovate at a pinned version with its whole config, config.js, which pipeline run-renovate runs to open upgrade PRs (docs/adr/0010). Check config.js with `npm run check` in that folder.
- `docs/adr`: one numbered file per design decision.
- A folder holds one kind of thing, so a new kind of file gets a folder of its own rather than joining one that holds something else. A Terraform root's .tf files stay together in one folder, since Terraform reads only the folder it runs in. Names say what a thing is for: a pipeline is named for what it acts on and what it does.

Project references point inward: Host references Infrastructure, Infrastructure references Application, and Application references Domain and Contracts. Domain and Contracts reference nothing. The AppHost references the projects it starts, and nothing references the AppHost.

## Build, test and run

- Work in the dev container: on the dev VM, open the repo in VS Code and choose Reopen in Container. After a change to `.devcontainer/`, run Dev Containers: Rebuild Container.
- InnerSource's packages, such as InnerSource.Telemetry, come from the innersource feed in Azure Artifacts, which nuget.config maps `InnerSource.*` to (docs/adr/0009). A restore reads the feed only for a version the package cache lacks, and then fails with 401 Unauthorized unless it has the feed's token. In the dev container, run that restore with a token from the Azure CLI's sign-in, set for that command only and never printed: `VSS_NUGET_URI_PREFIXES=https://pkgs.dev.azure.com/mikewicks-lab/ VSS_NUGET_ACCESSTOKEN="$(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken --output tsv)" dotnet restore`. If az says to run az login, ask the person to, since the sign-in needs them. The AI developer's pipeline restores before its agent starts, so its agent can't fetch a version main doesn't use.
- Build and test with `dotnet run build.cs`, the same command the pipelines run. It builds in Release, runs every test, packs, publishes the Host and the dacpac into artifacts/, and ends by printing the SDK, the version, the test count and the packages. It must pass with no warnings before a PR. `dotnet run build.cs -- test` stops after the tests, and `dotnet run build.cs -- --list-tree` shows every target and what it depends on. global.json pins the .NET 10 SDK and runs the tests on Microsoft Testing Platform, which is why `dotnet test` takes `--solution`.
- End every file you write with a newline, as .editorconfig asks. `dotnet run build.cs` checks every tracked text file for one first, and names any file without it.
- build.cs runs the tests with code coverage, which writes a Cobertura file to artifacts/test-results for SonarQube Cloud. Every test project references Microsoft.Testing.Extensions.CodeCoverage, since one without it fails on `--coverage`. Coverage counts only the assemblies a test loads, so give each project with code a test that uses it.
- Versions come from git tags through MinVer. A tag such as v1.2.0 makes its commit 1.2.0, and each later commit a pre-release of the next patch, such as 1.2.1-alpha.0.3 three commits on. MinVer needs the whole history and the tags, so build.cs stops in a shallow clone, and every pipeline checks out with `fetchDepth: 0` and `fetchTags: true` (docs/adr/0005).
- Run the solution locally with `dotnet run --project src/GroundWerk.AppHost`. It starts the Host as api and as jobs and prints a link to the Aspire dashboard, which shows each one's state, health and logs. Ctrl+C stops everything. To run one role on its own, use `dotnet run --project src/GroundWerk.Host`, adding `-- --Role=jobs` for the jobs.
- Coding agents and scripts use the Aspire CLI instead, since that command runs until Ctrl+C. The dev container has it at the version of Aspire.AppHost.Sdk in global.json, so run it as `aspire <command> --apphost src/GroundWerk.AppHost --non-interactive --nologo`, with the commands `start`, `wait <resource>`, `describe --format Json`, `logs <resource> --format Json`, `otel traces <resource> --format Json`, `otel logs <resource> --format Json` and `stop`. Outside the dev container, use `dotnet dnx --yes aspire.cli@<version> --` in place of `aspire`, with that version. Without `--format Json`, describe and logs print nothing when their output isn't a terminal. Never show the dashboard's login link or a resource's environment, since they hold the dashboard's token and keys.
- Never run `aspire publish` or `aspire deploy` (docs/adr/0003).
- Give every endpoint the AppHost makes a fixed port, as api has 5291 and jobs 5292, so each run uses the same ports and the dev container's Ports tab lists only those.

## Code

- Directory.Build.props sets .NET 10, nullable reference types, implicit usings, the recommended analyzers and warnings as errors for every C# project, so project files don't repeat them. Fix a warning rather than suppress it, and never lower those settings.
- Package versions live only in Directory.Packages.props. Add a package with `dotnet add <project> package <name>`, which records its version there.
- Code that only this repo uses is a project reference, never a package.
- build.cs packs only the projects in its packageProjects list, which stays empty until a project ships as a package.
- File-scoped namespaces that match the folder.
- Log through `[LoggerMessage]` source-generated methods, since the analyzers fail the build on calls such as `LogInformation`.
- Remove unused using directives from the files you change, since the build doesn't flag them.
- The Host sets up OpenTelemetry with `builder.AddTelemetry()` from the InnerSource.Telemetry package, so a `[LoggerMessage]` method's values become fields of its log record, and each role's traces, metrics and logs show on the AppHost's dashboard.
- Generic names only: no company, product or customer names in code, configuration or docs, since main is mirrored to a public repo.
- No secrets in the repo: no tokens, keys, passwords or connection strings that hold them. Configuration reads them from the environment or Key Vault. The dev container's pre-commit hook refuses a commit that holds one, so take the secret out rather than skip the hook with `--no-verify`.
- EF Core's mapping rules go in this file before the first entity.

## Tests

- Every behavior change comes with tests.
- Unit tests use xUnit v3. Test names say what they check, in PascalCase.
- Tests reach a container that Testcontainers starts at its `Hostname` and mapped port, never at localhost, since in the dev container and in a container job, Docker runs outside the tests' own container (docs/adr/0007).

## Branches, commits and PRs

- In Claude Code, take a user story or bug to a PR with `/work-on-user-story <ID>`, which follows these rules and codes through story-coder.
- Branch from main as `story/<ID>-<short-name>` or `bug/<ID>-<short-name>`, with the work item's ID. main refuses direct pushes.
- End each commit message on the branch with `#<ID>`.
- Title the PR `<Type> <ID>: <what it does>`, in sentence case, with no `#ID` and no period, such as `Bug 49: Remove groundwerk-azdo's ownership of itself`, and link it to its work item.
- Complete it with a squash merge whose message is `Merged PR <N>: ` followed by the PR's title, such as `Merged PR 5: Bug 49: Remove groundwerk-azdo's ownership of itself`, and delete the branch. Completing a PR doesn't close its work item.
- Once the PR is completed and its work item closed, run `git fetch --prune` and delete the local branch with `git branch -D`. Check that the PR shows as completed first, since after a squash merge git can't tell the branch was merged.
- A PR needs an approval from someone other than its author and its last pusher, and its comments resolved. Coding agents never approve or vote on a PR, bypass a policy or run a pipeline.
- Every PR into main runs pipeline build-groundwerk unless it changes only docs or Markdown files: gitleaks scans each of its commits for secrets, then build.cs runs inside SonarQube Cloud's analysis, and a secret, a failing test or a failed quality gate fails it and blocks the PR (docs/adr/0008). The gate asks for 80% coverage of new code. The scanner turns warnings-as-errors off, so the PR build doesn't catch a compiler warning, and build.cs must pass before the PR. A draft PR gets no PR build until it's published.
- The AI developer creates branches and opens PRs as groundwerk-ai-developer, but it can't push to main or to a branch it didn't create, or complete a PR, so a person approves and completes its PRs. Tag a user story or bug ai-developer to let it take that item.
- Renovate opens upgrade PRs as groundwerk-renovate from branches that start with renovate/, each linked to Feature 21, and a person approves and completes them. Don't push to its branches, since Renovate then stops updating them. From a minimum version's deadline in infra/azdo/minimum-versions.tf on, every build that uses an older version of that package fails until it reaches the minimum, usually through Renovate's PR (docs/adr/0010).

## Definitions of Ready and Done

The wiki page Definitions of Done and Ready holds these too, so change both together.

Definition of Ready
- A why, and acceptance criteria the product owner has signed off.
- Two or three days of work, or split.
- Dependencies and the test approach named.
- Not blocked on an open decision.
- How you'll see it working beyond its tests, such as a trace in a dashboard, a blocked PR or a resource in the portal.

Definition of Done
- A linked work item.
- Approved by someone other than the author.
- Tests for every behavior change, with a green build and the SonarQube gate.
- AGENTS.md updated when a convention changes.
- Each design decision recorded as an ADR in docs/adr, naming the alternative it was chosen over.
- Telemetry and log fields on new paths.
- Deployed to ci, from phase 3.
- The story's state updated.

## Board states

- **New:** not started.
- **Active:** work has started. A story goes Active when its branch is made.
- **Closed:** the change is live and checked: after the apply for infrastructure, and after the deploy to ci for code from phase 3. Completing a PR doesn't close its story.
- **Removed:** dropped. Work items are never deleted.
- A Feature or Epic goes Active when its first child does, and Closed when all its children are Closed.
