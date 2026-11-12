# AGENTS.md

How to work in GroundWerk, for people and coding agents. A PR that changes a convention changes this file too.

## Layout

- `GroundWerk.slnx` is the one solution. Add each new project to it with `dotnet sln GroundWerk.slnx add`.
- `build.cs`: the build script, which .NET 10 runs as a file-based app. Its Bullseye targets restore, build, test, pack and publish, so a pipeline's YAML only runs it (docs/adr/0005). Its `#:package` lines carry no versions, since those live in Directory.Packages.props.
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
- A pipeline that can reach a secret or a service connection keeps it behind an Only main check, since a push to any branch can start a pipeline with that branch's copy of its YAML (docs/adr/0006).
- `tools/`: one folder per tool that a pipeline runs and that isn't part of the product. `tools/ai-developer` is the AI developer, which pipeline ai-developer runs to take one user story or bug tagged ai-developer to one PR (docs/adr/0006). Check and test it with `npm run check` and `npm test` in that folder.
- `docs/adr`: one numbered file per design decision.
- A folder holds one kind of thing, so a new kind of file gets a folder of its own rather than joining one that holds something else. A Terraform root's .tf files stay together in one folder, since Terraform reads only the folder it runs in. Names say what a thing is for: a pipeline is named for what it acts on and what it does.

Project references point inward: Host references Infrastructure, Infrastructure references Application, and Application references Domain and Contracts. Domain and Contracts reference nothing. The AppHost references the projects it starts, and nothing references the AppHost.

## Build, test and run

- Build and test with `dotnet run build.cs`, the same command the pipelines run. It builds in Release, runs every test, packs, publishes the Host and the dacpac into artifacts/, and ends by printing the SDK, the version, the test count and the packages. It must pass with no warnings before a PR. `dotnet run build.cs -- test` stops after the tests, and `dotnet run build.cs -- --list-tree` shows every target and what it depends on. global.json pins the .NET 10 SDK and runs the tests on Microsoft Testing Platform, which is why `dotnet test` takes `--solution`.
- Versions come from git tags through MinVer. A tag such as v1.2.0 makes its commit 1.2.0, and each later commit a pre-release of the next patch, such as 1.2.1-alpha.0.3 three commits on. MinVer needs the whole history and the tags, so build.cs stops in a shallow clone, and every pipeline checks out with `fetchDepth: 0` and `fetchTags: true` (docs/adr/0005).
- Run the solution locally with `dotnet run --project src/GroundWerk.AppHost`. It starts the Host as api and as jobs and prints a link to the Aspire dashboard, which shows each one's state, health and logs. Ctrl+C stops everything. To run one role on its own, use `dotnet run --project src/GroundWerk.Host`, adding `-- --Role=jobs` for the jobs.
- Coding agents and scripts use the Aspire CLI instead, since that command runs until Ctrl+C. Run it as `dotnet dnx --yes aspire.cli@<version> -- <command> --apphost src/GroundWerk.AppHost --non-interactive --nologo`, with the version of Aspire.AppHost.Sdk in global.json, and the commands `start`, `wait <resource>`, `describe --format Json`, `logs <resource> --format Json` and `stop`. Without `--format Json`, describe and logs print nothing when their output isn't a terminal. Never show the dashboard's login link or a resource's environment, since they hold the dashboard's token and keys.
- Never run `aspire publish` or `aspire deploy` (docs/adr/0003).

## Code

- Directory.Build.props sets .NET 10, nullable reference types, implicit usings, the recommended analyzers and warnings as errors for every C# project, so project files don't repeat them. Fix a warning rather than suppress it, and never lower those settings.
- Package versions live only in Directory.Packages.props. Add a package with `dotnet add <project> package <name>`, which records its version there.
- Code that only this repo uses is a project reference, never a package.
- build.cs packs only the projects in its packageProjects list, which stays empty until a project ships as a package.
- File-scoped namespaces that match the folder.
- Log through `[LoggerMessage]` source-generated methods, since the analyzers fail the build on calls such as `LogInformation`.
- Generic names only: no company, product or customer names in code, configuration or docs, since main is mirrored to a public repo.
- No secrets in the repo: no tokens, keys, passwords or connection strings that hold them. Configuration reads them from the environment or Key Vault.
- EF Core's mapping rules go in this file before the first entity.

## Tests

- Every behavior change comes with tests.
- Unit tests use xUnit v3. Test names say what they check, in PascalCase.

## Branches, commits and PRs

- Branch from main as `story/<ID>-<short-name>` or `bug/<ID>-<short-name>`, with the work item's ID. main refuses direct pushes.
- End each commit message on the branch with `#<ID>`.
- Title the PR `<Type> <ID>: <what it does>`, in sentence case, with no `#ID` and no period, such as `Bug 49: Remove groundwerk-azdo's ownership of itself`, and link it to its work item.
- Complete it with a squash merge whose message is `Merged PR <N>: ` followed by the PR's title, such as `Merged PR 5: Bug 49: Remove groundwerk-azdo's ownership of itself`, and delete the branch. Completing a PR doesn't close its work item.
- Once the PR is completed and its work item closed, run `git fetch --prune` and delete the local branch with `git branch -D`. Check that the PR shows as completed first, since after a squash merge git can't tell the branch was merged.
- A PR needs an approval from someone other than its author and its last pusher, and its comments resolved. Coding agents never approve or vote on a PR, bypass a policy or run a pipeline.
- The AI developer creates branches and opens PRs as groundwerk-ai-developer, but it can't push to main or to a branch it didn't create, or complete a PR, so a person approves and completes its PRs. Tag a user story or bug ai-developer to let it take that item.

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
