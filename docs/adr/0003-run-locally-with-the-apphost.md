# 3. Run the solution locally with an Aspire AppHost

Status: Accepted

## Context

The Host runs as two processes, the API and the jobs (docs/adr/0002). Phase 2 adds SQL Server 2025, Redis, the Event Hubs emulator and Azurite, which local runs and integration tests need too. Starting each one by hand, with its own port, Role and settings, is slow and differs from one machine to the next.

## Decision

src/GroundWerk.AppHost is an Aspire AppHost, and `dotnet run --project src/GroundWerk.AppHost` is how to run the solution locally. It starts the Host twice, as api and as jobs, each with a health check on /health, and the Aspire dashboard shows their state, health and logs. Phase 2 adds its dependencies to the same AppHost. The AppHost is for local runs and tests only: deploys stay Helm and Terraform, so the repo never uses `aspire publish` or `aspire deploy`. global.json pins the Aspire SDK's version.

## Alternatives considered

- Docker Compose for the dependencies, with the Host started by hand in each role, which leaves ports, Role values and settings to each developer and has no dashboard for logs and health.
- Aspire's publish and deploy, which would make the AppHost a second description of production beside the Helm charts and Terraform.

## Consequences

- One command starts everything with the right Role and settings, and the dashboard shows whether each part is healthy.
- The first build downloads the Aspire CLI bundle, about 150 MB, into the NuGet cache, so the dev container and CI should cache it.
- The dashboard serves plain http on localhost, so it's opened on the dev machine or through an SSH tunnel. Its login link holds a token, so it isn't shared.
