# 7. One image for the dev container and the build

Status: Accepted

## Context

A build on a dev machine should use the same tools, at the same versions, as the pipeline's, so a failure in one can be reproduced in the other. Those tools are the .NET 10 SDK, the Azure CLI, kubectl, Helm, Terraform, SqlPackage, k6, Trivy, gitleaks, Node.js and the Aspire CLI. Integration tests start containers with Testcontainers, so wherever they run needs a Docker daemon. And main is mirrored to a public repo, so a secret has to be stopped before it's committed.

## Decision

- .devcontainer/Dockerfile builds one x64 image on Microsoft's .NET 10 SDK image for Ubuntu 24.04, pinned by digest. VS Code opens the repo in it as a dev container, and the pipelines run their jobs in it as container jobs.
- Every tool is pinned to a version, and each one the Dockerfile downloads is checked against the SHA-256 its publisher lists, so the image changes only through a PR.
- The image stays root with no ENTRYPOINT, since a container job's agent adds its own user with groupadd and useradd before it runs a step. VS Code signs in to the dev container as ubuntu, the base image's user, through remoteUser in devcontainer.json.
- Containers that tests start run beside the image's container, not inside it. The dev container uses the dev VM's Docker through its socket, with the docker-outside-of-docker feature, and a container job maps the agent's socket with mapDockerSocket. Tests reach those containers at Testcontainers' Hostname and mapped port, the Docker host's address, never at localhost.
- A pre-commit hook runs gitleaks on the staged changes. The image sets core.hooksPath in git's system config, so the hook runs in every clone in the container with no setup.
- The Aspire CLI is installed for ubuntu, at the Aspire.AppHost.Sdk version in global.json, for VS Code's Aspire extension and the AppHost's build. A container job's user gets it through dnx, as on a hosted agent.
- Every endpoint the AppHost makes has a fixed port, which Aspire labels for VS Code in the dev container, and devcontainer.json leaves every other port unforwarded, so VS Code's Ports tab lists the same ports each run.
- Claude Code's sign-in and settings, and NuGet's package cache, live in Docker volumes that a rebuild keeps. The dev VM's Azure CLI sign-in and SSH known_hosts are mounted into the container, so az, the Azure DevOps MCP server and git over SSH work as they do on the VM, with the SSH key still forwarded from the developer's own machine.

## Alternatives considered

- Microsoft's devcontainers/dotnet image, which is made for VS Code with a user of its own and gets each SDK patch later than the SDK image, or plain Ubuntu with .NET installed by hand.
- Docker-in-Docker, which runs a second Docker daemon in a privileged container.
- Tools installed on each dev machine, which no pipeline shares and which drift apart.
- One copy of the Aspire CLI for every user, which hung for every user but its owner, since the CLI unpacks its dashboard and orchestrator beside itself and takes a lock there.
- A script that each clone runs to install the hook, which a clone can skip, or the pre-commit framework, which needs Python and a config file in each repo.
- InnerSource and PipelineTemplates in this image now, which needs the image in a registry they can pull it from, or a copy of the Dockerfile in each repo, which would drift.

## Consequences

- To move a tool to a new version, change its version and checksum together. A change to Aspire.AppHost.Sdk in global.json changes ASPIRE_CLI_VERSION in the Dockerfile in the same PR.
- After a change to .devcontainer, VS Code needs Dev Containers: Rebuild Container.
- The dev container is a toolchain, not a sandbox. Through the Docker socket and the mounted sign-ins it can do what the dev VM's user can, so Claude Code in it keeps its permission prompts, as on the VM.
- A commit holding a secret is refused in the container. The hook can be skipped with --no-verify, which AGENTS.md forbids, so only a check in the PR build can make it binding.
- A container job pulls its image from a registry, so the image has to be in one before a pipeline can run in it.
